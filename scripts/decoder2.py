"""
Created on May 17, 2013
@author: tanel
"""
from __future__ import print_function
import gi

gi.require_version('Gst', '1.0')
from gi.repository import GObject, Gst

GObject.threads_init()
Gst.init(None)
import os,sys
import logging
import locale
if locale.getpreferredencoding().upper() != 'UTF-8': 
    locale.setlocale(locale.LC_ALL, 'en_US.UTF-8') 

if sys.version_info[0] < 3:
  import thread
else:
  import _thread as thread
from collections import OrderedDict

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

logger = logging.getLogger(__name__)

import pdb
import requests
import json
import gc


SUD_API                      = os.getenv('SUD_API', '')

MODEL_DIR=os.getenv('MODEL_DIR', '')
SUD_EnAPI='http://40.90.168.84:8060/punctuate'
SUD_CnAPI='http://40.90.169.207:8061/punctuate'

sud_enable                   = str(os.getenv('USING_SUD', 'no')).lower().strip()
text_normalization_enable    = str(os.getenv('TEXT_NORMALIZATION', 'no')).lower().strip()

CONTAINER=""


def sendToSUD(inputUtterance):
    if ('mandarin' in MODEL_DIR.lower()):
        SUD_API = SUD_CnAPI

    headers = {"accept": "application/json"}
    payload = {"input_text": inputUtterance}
    r = requests.post(url = SUD_API, headers=headers, data=payload)
	
    data = r.json()
    return data['result']

def normalizedText(inputText):
    escaped_text = inputText.replace("'", "\'")
    norm_command = 'echo "' + escaped_text + '" | normalize-english-number-text - -'
    #os.system(norm_command)
    output_text = os.popen(norm_command).read().strip()
    return output_text 

def disfluenciesRemover(inString):
    disfluencies = [
        'uh',
        'um',
        'oh',
        'er',
        'em',
        'ah',
        'lah',
        'huh',
        'hmm',
        'erm',
        '<v-noise>',
        '<noise>',
    ]
    newline = ''
    words = inString.split()
    for word in words:
        if word.strip().lower() in disfluencies:
            continue
        else:
            newline += word + ' '    
    return newline.strip()


class DecoderPipeline2(object):
    def __init__(self, conf={}):
        logger.info("Creating decoder using conf: %s" % conf)
        self.create_pipeline(conf)
        self.outdir = conf.get("out-dir", None)
        if self.outdir:
            if not os.path.exists(self.outdir):
                os.makedirs(self.outdir)
            elif not os.path.isdir(self.outdir):
                raise Exception("Output directory %s already exists as a file" % self.outdir)

        self.result_handler = None
        self.full_result_handler = None
        self.eos_handler = None
        self.error_handler = None
        self.request_id = "<undefined>"
        # self.remote_ip = "<undefined>"

    def create_pipeline(self, conf):

        self.appsrc = Gst.ElementFactory.make("appsrc", "appsrc")
        self.decodebin = Gst.ElementFactory.make("decodebin", "decodebin")
        self.audioconvert = Gst.ElementFactory.make("audioconvert", "audioconvert")
        self.audioresample = Gst.ElementFactory.make("audioresample", "audioresample")
        self.tee = Gst.ElementFactory.make("tee", "tee")
        self.queue1 = Gst.ElementFactory.make("queue", "queue1")
        self.filesink = Gst.ElementFactory.make("filesink", "filesink")
        self.queue2 = Gst.ElementFactory.make("queue", "queue2")
        self.asr = Gst.ElementFactory.make("kaldinnet2onlinedecoder", "asr")
        self.fakesink = Gst.ElementFactory.make("fakesink", "fakesink")

        if not self.asr:
            #print >> sys.stderr, "ERROR: Couldn't create the kaldinnet2onlinedecoder element!"
            eprint("ERROR: Couldn't create the kaldinnet2onlinedecoder element!")
            gst_plugin_path = os.environ.get("GST_PLUGIN_PATH")
            if gst_plugin_path:
                #print >> sys.stderr, \
                eprint(
                    "Couldn't find kaldinnet2onlinedecoder element at %s. " \
                    "If it's not the right path, try to set GST_PLUGIN_PATH to the right one, and retry. " \
                    "You can also try to run the following command: " \
                    "'GST_PLUGIN_PATH=%s gst-inspect-1.0 kaldinnet2onlinedecoder'." \
                    % (gst_plugin_path, gst_plugin_path))
            else:
                #print >> sys.stderr, \
                eprint(
                    "The environment variable GST_PLUGIN_PATH wasn't set or it's empty. " \
                    "Try to set GST_PLUGIN_PATH environment variable, and retry.")
            sys.exit(-1);

        # This needs to be set first
        if "use-threaded-decoder" in conf["decoder"]:
            self.asr.set_property("use-threaded-decoder", conf["decoder"]["use-threaded-decoder"])

        decoder_config = conf.get("decoder", {})
        if 'nnet-mode' in decoder_config:
          logger.info("Setting decoder property: %s = %s" % ('nnet-mode', decoder_config['nnet-mode']))
          self.asr.set_property('nnet-mode', decoder_config['nnet-mode'])
          del decoder_config['nnet-mode']

        decoder_config = OrderedDict(decoder_config)

        if "fst" in decoder_config:
            decoder_config["fst"] = decoder_config.pop("fst")
        if "model" in decoder_config:
            decoder_config["model"] = decoder_config.pop("model")
        
        if sys.version_info[0] < 3:
            for (key, val) in decoder_config.iteritems():
                if key != "use-threaded-decoder":
                    logger.info("Setting decoder property: %s = %s" % (key, val))
                    self.asr.set_property(key, val)
        else:
            for (key, val) in decoder_config.items():
                if key != "use-threaded-decoder":
                    logger.info("Setting decoder property: %s = %s" % (key, val))
                    self.asr.set_property(key, val)
        
        self.appsrc.set_property("is-live", True)
        self.filesink.set_property("location", "/dev/null")
        logger.info('Created GStreamer elements')

        self.pipeline = Gst.Pipeline()
        for element in [self.appsrc, self.decodebin, self.audioconvert, self.audioresample, self.tee,
                        self.queue1, self.filesink, 
                        self.queue2, self.asr, self.fakesink]:
            logger.debug("Adding %s to the pipeline" % element)
            self.pipeline.add(element)

        logger.info('Linking GStreamer elements')

        self.appsrc.link(self.decodebin)
        #self.appsrc.link(self.audioconvert)
        self.decodebin.connect('pad-added', self._connect_decoder)
        self.audioconvert.link(self.audioresample)

        self.audioresample.link(self.tee)

        self.tee.link(self.queue1)
        self.queue1.link(self.filesink)
        
        self.tee.link(self.queue2)
        self.queue2.link(self.asr)

        self.asr.link(self.fakesink)

        # Create bus and connect several handlers
        self.bus = self.pipeline.get_bus()
        self.bus.add_signal_watch()
        self.bus.enable_sync_message_emission()
        self.bus.connect('message::eos', self._on_eos)
        self.bus.connect('message::error', self._on_error)
        #self.bus.connect('message::cutter', self._on_cutter)

        self.asr.connect('partial-result', self._on_partial_result)
        self.asr.connect('final-result', self._on_final_result)
        self.asr.connect('full-final-result', self._on_full_final_result)

        logger.info("Setting pipeline to READY")
        self.pipeline.set_state(Gst.State.READY)
        logger.info("Set pipeline to READY")

    def _connect_decoder(self, element, pad):
        logger.info("%s: Connecting audio decoder" % (self.request_id))
        pad.link(self.audioconvert.get_static_pad("sink"))
        logger.info("%s: Connected audio decoder" % (self.request_id))

    def _on_partial_result(self, asr, hyp):
        decoded_hyp = hyp
        if sys.version_info[0] < 3:
            decoded_hyp = hyp.decode('utf8')

        logger.info("%s: Got partial result: %s" % (self.request_id, decoded_hyp))
        if self.result_handler:
            self.result_handler(decoded_hyp, False)

    def _on_final_result(self, asr, hyp):
        final_hyp = hyp
        if sys.version_info[0] < 3:
            final_hyp = hyp.decode('utf8')

        final_hyp = disfluenciesRemover(final_hyp)
        logger.info("%s: Got final result: %s" % (self.request_id, final_hyp))
        if ('yes' == text_normalization_enable):
            final_hyp = normalizedText(final_hyp)
        if ('yes' == sud_enable) or ('mandarin' in MODEL_DIR.lower()):
            final_hyp = sendToSUD(final_hyp)
            logger.info("%s: Got final result (after sud): %s" % (self.request_id, final_hyp))

        if self.result_handler:
            self.result_handler(final_hyp, True)
        
        # Write to the text file
        with open(os.path.join(self.outdir, (str(self.request_id)) + ".txt"), "a") as myfile:
            myfile.write(final_hyp)
            myfile.write("\n")

    def _on_full_final_result(self, asr, result_json):
        full_final_json = result_json
        if sys.version_info[0] < 3:
            full_final_json = result_json.decode('utf8')
        logger.info("%s:  Got full final result: %s" % (self.request_id, full_final_json))
        
        event = json.loads(full_final_json)
        best_hypothesis = disfluenciesRemover(event["result"]["hypotheses"][0]["transcript"])
        
        if ('yes' == text_normalization_enable):
            best_hypothesis = normalizedText(best_hypothesis)
        if ('yes' == sud_enable) or ('mandarin' in MODEL_DIR.lower()):
            best_hypothesis = sendToSUD(best_hypothesis)
            logger.info("%s: Got full final result (after sud): %s" % (self.request_id, best_hypothesis))
        
        event["result"]["hypotheses"][0]["transcript"] = best_hypothesis
        full_final_json = json.dumps(event)
        
        if self.full_result_handler:
            logger.info("%s: Send full final result to worker : %s" % (self.request_id, full_final_json))
            self.full_result_handler(full_final_json)

    def _on_error(self, bus, msg):
        self.error = msg.parse_error()
        logger.error(self.error)
        self.finish_request()
        if self.error_handler:
            self.error_handler(self.error[0].message)

    def _on_eos(self, bus, msg):
        logger.info('%s: Pipeline received eos signal' % (self.request_id))
        #self.decodebin.unlink(self.audioconvert)
        self.finish_request()
        if self.eos_handler:
            self.eos_handler[0](self.eos_handler[1])
            logger.info('%s: From decoder: ALL FINISHED PROPERLY' % (self.request_id))

    def get_adaptation_state(self):
        logger.info("Started returning adaptation-state")
        try:
            return self.asr.get_property("adaptation-state")
        except:
            return self.asr.get_property(b"adaptation-state")

    def set_adaptation_state(self, adaptation_state):
        """Sets the adaptation state to a certian value, previously retrieved using get_adaptation_state()
        Should be called after init_request(..)
        """
        return self.asr.set_property("adaptation-state", adaptation_state)

    def finish_request(self):
        logger.info("%s: Resetting decoder state" % (self.request_id))
        if self.outdir:
            self.filesink.set_state(Gst.State.NULL)
            self.filesink.set_property('location', "/dev/null")
            self.filesink.set_state(Gst.State.PLAYING)
            
        logger.info("%s: Set the pipeline state to NULL" % (self.request_id))
        self.pipeline.set_state(Gst.State.NULL)
        #try:
        #    #
        #    self.upload_to_cloud("%s/%s.raw" % (self.outdir, self.request_id))
        #    self.upload_to_cloud("%s/%s.txt" % (self.outdir, self.request_id))
        #except:
        #    logger.info("%s: Exception while uploading to cloud" % (self.request_id))

        self.request_id = "<undefined>"
        logger.info("%s: Set the pipeline state to NULL: FINISHED." % (self.request_id))


    def init_request(self, id, caps_str):
        self.request_id = id
        #self.remote_ip = remote_ip   
        logger.info("%s: Initializing request" % (self.request_id))
        if caps_str and len(caps_str) > 0:
            logger.info("%s: Setting caps to %s" % (self.request_id, caps_str))
            caps = Gst.caps_from_string(caps_str)
            self.appsrc.set_property("caps", caps)
        else:
            #caps = Gst.caps_from_string("")
            self.appsrc.set_property("caps", None)
            #self.pipeline.set_state(Gst.State.READY)
            pass
        #self.appsrc.set_state(Gst.State.PAUSED)

        if self.outdir:
            self.pipeline.set_state(Gst.State.PAUSED)
            self.filesink.set_state(Gst.State.NULL)
            self.filesink.set_property('location', "%s/%s.raw" % (self.outdir, id))
            self.filesink.set_state(Gst.State.PLAYING)

        #self.filesink.set_state(Gst.State.PLAYING)
        #self.decodebin.set_state(Gst.State.PLAYING)
        self.pipeline.set_state(Gst.State.PLAYING)
        self.filesink.set_state(Gst.State.PLAYING)
        # push empty buffer (to avoid hang on client diconnect)
        #buf = Gst.Buffer.new_allocate(None, 0, None)
        #self.appsrc.emit("push-buffer", buf)

        # reset adaptation state
        self.set_adaptation_state("")

    def process_data(self, data):
        logger.debug('%s: Pushing buffer of size %d with type %s to pipeline' % (self.request_id, len(data), type(data)))
        #gc.set_debug(gc.DEBUG_LEAK)
        buf = Gst.Buffer.new_allocate(None, len(data), None)
        buf.fill(0, data)
        self.appsrc.emit("push-buffer", buf)
        logger.debug('%s: Pushing buffer done' % (self.request_id))
        gc.collect()

    def end_request(self):
        logger.info("%s: Pushing EOS to pipeline" % (self.request_id))
        self.appsrc.emit("end-of-stream")

    def set_result_handler(self, handler):
        self.result_handler = handler

    def set_full_result_handler(self, handler):
        self.full_result_handler = handler

    def set_eos_handler(self, handler, user_data=None):
        self.eos_handler = (handler, user_data)

    def set_error_handler(self, handler):
        self.error_handler = handler


    def cancel(self):
        logger.info("%s: Sending EOS to pipeline in order to cancel processing" % (self.request_id))
        self.appsrc.emit("end-of-stream")
        #self.asr.set_property("silent", True)
        #self.pipeline.set_state(Gst.State.NULL)

        #if (self.pipeline.get_state() == Gst.State.PLAYING):
        #logger.debug("Sending EOS to pipeline")
        #self.pipeline.send_event(Gst.Event.new_eos())
        #self.pipeline.set_state(Gst.State.READY)
        logger.info("%s: Cancelled pipeline" % (self.request_id))

    def upload_to_cloud(self, full_file_path):
        local_file_name = os.path.basename(full_file_path)
        logger.info("\nUploading to Blob storage as blob " + local_file_name)
        self.block_blob_service.create_blob_from_path(CONTAINER, local_file_name, full_file_path)


