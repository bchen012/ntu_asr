# pylint: disable=import-error
#!/usr/bin/env python
#
# Copyright 2013 Tanel Alumae

"""
Reads speech data via websocket requests, sends it to Redis, waits for results from Redis and
forwards to client via websocket
"""
import sys
import logging
import json
import codecs
import os.path
import uuid
import time
import threading
import functools
# for python 2
#from Queue import Queue
# for python 3
from queue import Queue
import tornado.ioloop
import tornado.options
import tornado.web
import tornado.websocket
import tornado.gen
import tornado.concurrent
import concurrent.futures
import settings
import common
import master_server_addon
import prometheus_client as prom

# create logger
logger = logging.getLogger('master_server')
logger.setLevel(logging.DEBUG)

# create console handler and set level to debug
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
logfh = logging.handlers.RotatingFileHandler('master_server.log', maxBytes=31457280, backupCount=10) #30Mb
logfh.setLevel(logging.DEBUG)

# create formatter
formatter = logging.Formatter(u'%(levelname)8s %(asctime)s %(message)s ')
logging._defaultFormatter = logging.Formatter(u"%(message)s")

# add formatter to ch
ch.setFormatter(formatter)
logfh.setFormatter(formatter)

# add ch to logger
logger.addHandler(ch)
logger.addHandler(logfh)


num_req = prom.Counter('number_of_request_receive_by_master',
                       'number of request receive by master')
num_worker = prom.Gauge('number_of_worker_available',
                        'number of worker available')
num_req_reject = prom.Counter(
        'number_of_request_reject', 'number_of_request_reject')

class Application(tornado.web.Application):
    def __init__(self):
        settings = dict(
            cookie_secret="43oETzKXQAGaYdkL5gEmGeJJFuYh7EQnp2XdTP1o/Vo=",
            template_path=os.path.join(os.path.dirname(
                os.path.dirname(__file__)), "templates"),
            static_path=os.path.join(os.path.dirname(
                os.path.dirname(__file__)), "static"),
            xsrf_cookies=False,
            autoescape=None
        )

        handlers = [
            (r"/", MainHandler),
            (r"/test", TestConnectionHandler),
            #(r"/.well-known/acme-challenge/(.*)", tornado.web.StaticFileHandler, {'path': '/home/appuser/opt/ssl/verify/'}),
            (r"/client/ws/speech", DecoderSocketHandler),
            (r"/client/ws/status", StatusSocketHandler),
            # (r"/client/dynamic/reference", ReferenceHandler),
            (r"/client/dynamic/recognize", HttpChunkedRecognizeHandler),
            (r"/worker/ws/speech", WorkerSocketHandler),
            (r"/client/static/(.*)", tornado.web.StaticFileHandler,
             {'path': settings["static_path"]}),
            # (r"/prepare_job", HttpPrepareJobHandler),

        ]
        tornado.web.Application.__init__(self, handlers, **settings)
        self.available_workers = {}
        self.status_listeners = set()
        self.num_requests_processed = 0

    def send_status_update_single(self, ws):
        status = dict(num_workers_available=[{k: len(v)} for k, v in self.available_workers.items(
        )], num_requests_processed=self.num_requests_processed)
        ws.write_message(json.dumps(status))

    def send_status_update(self):
        for ws in self.status_listeners:
            self.send_status_update_single(ws)

    def save_reference(self, content_id, content):
        refs = {}
        try:
            with open("reference-content.json") as f:
                refs = json.load(f)
        except:
            pass
        refs[content_id] = content
        with open("reference-content.json", "w") as f:
            json.dump(refs, f, indent=2)


class MainHandler(tornado.web.RequestHandler):
    def get(self):
        self.set_status(200)
        self.finish("Speechlab Streamer")


class TestConnectionHandler(tornado.web.RequestHandler):
    def get(self):
        self.set_status(200)
        self.finish("Speechlab Streamer Connection Test Successful")
        logger.info("Speechlab Streamer connection is tested")


def content_type_to_caps(content_type):
    """
    Converts MIME-style raw audio content type specifier to GStreamer CAPS string
    """
    default_attributes = {"rate": 16000, "format": "S16LE",
                          "channels": 1, "layout": "interleaved"}
    media_type, _, attr_string = content_type.replace(";", ",").partition(",")
    if media_type in ["audio/x-raw", "audio/x-raw-int"]:
        media_type = "audio/x-raw"
        attributes = default_attributes
        for (key, _, value) in [p.partition("=") for p in attr_string.split(",")]:
            attributes[key.strip()] = value.strip()
        return "%s, %s" % (media_type, ", ".join(["%s=%s" % (key, value) for (key, value) in attributes.iteritems()]))
    else:
        return content_type

class SpawnWorker(threading.Thread):
    def __init__(self, model=None, *args, **kwargs):
        super(SpawnWorker, self).__init__(*args, **kwargs)
        self.model = model

    def run(self):
        logger.info("Begin to spawn another worker of model: "+ str(self.model))
        master_server_addon.spawn_worker(self.model)
        logger.info("Spawn another worker")


@tornado.web.stream_request_body
class HttpChunkedRecognizeHandler(tornado.web.RequestHandler):
    """
    Provides a HTTP POST/PUT interface supporting chunked transfer requests, similar to that provided by
    http://github.com/alumae/ruby-pocketsphinx-server.
    """

    def prepare(self):
        self.id = str(uuid.uuid4())
        self.final_hyp = ""
        self.final_result_queue = Queue()
        self.user_id = self.request.headers.get("device-id", "none")
        self.content_id = self.request.headers.get("content-id", "none")
        logger.info("%s: OPEN: user='%s', content='%s'" %
                     (self.id, self.user_id, self.content_id))
        self.worker = None
        self.error_status = 0
        self.error_message = None
        # Waiter thread for final hypothesis:
        self.executor = concurrent.futures.ThreadPoolExecutor(max_workers=1)

        model = self.request.headers.get("model", "UNKNOWN_MODEL")
        logger.info("client with http requested model:"+str(model))

        try:
            spawn_worker = (model not in list(self.application.available_workers.keys())) or len(
                self.application.available_workers[model]) <= 5
            if spawn_worker:
                logger.info('no available workers for model: {}, spawning new worker'.format(model))
                SpawnWorker(model=model).start()

            self.worker = self.application.available_workers[model].pop()
            self.application.send_status_update()
            logger.info("%s: Using worker %s" % (self.id, self.__str__()))
            self.worker.set_client_socket(self)

            content_type = self.request.headers.get("Content-Type", None)
            if content_type:
                content_type = content_type_to_caps(content_type)
                logger.info("%s: Using content type: %s" %
                             (self.id, content_type))

            self.worker.write_message(json.dumps(dict(
                id=self.id, content_type=content_type, user_id=self.user_id, content_id=self.content_id)))
        except KeyError:
            logger.warn(
                "%s: No worker available for client request" % self.id)
            logger.exception("no available worker error message")
            self.set_status(503)
            self.finish("No workers available, please re-try 60 seconds later")

    def data_received(self, chunk):
        assert self.worker is not None
        logger.debug("%s: Forwarding client message of length %d to worker" % (
            self.id, len(chunk)))
        self.worker.write_message(chunk, binary=True)

    def post(self, *args, **kwargs):
        self.end_request(args, kwargs)

    def put(self, *args, **kwargs):
        self.end_request(args, kwargs)

    @tornado.concurrent.run_on_executor
    def get_final_hyp(self):
        logger.info("%s: Waiting for final result..." % self.id)
        return self.final_result_queue.get(block=True)

    @tornado.web.asynchronous
    @tornado.gen.coroutine
    def end_request(self, *args, **kwargs):
        logger.info(
            "%s: Handling the end of chunked recognize request" % self.id)
        assert self.worker is not None
        self.worker.write_message("EOS", binary=True)
        logger.info("%s: yielding..." % self.id)
        hyp = yield self.get_final_hyp()
        if self.error_status == 0:
            logger.info("%s: Final hyp: %s" % (self.id, hyp))
            response = {"status": 0, "id": self.id,
                        "hypotheses": [{"utterance": hyp}]}
            self.write(response)
        else:
            logger.info("%s: Error (status=%d) processing HTTP request: %s" % (
                self.id, self.error_status, self.error_message))
            response = {"status": self.error_status,
                        "id": self.id, "message": self.error_message}
            self.write(response)
        self.application.num_requests_processed += 1
        self.application.send_status_update()
        self.worker.set_client_socket(None)
        self.worker.close()
        self.finish()
        logger.info("Everything done")

    def send_event(self, event):
        event_str = str(event)
        if len(event_str) > 100:
            event_str = event_str[:97] + "..."
        logger.info("%s: Receiving event %s from worker" %
                     (self.id, event_str))
        if event["status"] == 0 and ("result" in event):
            try:
                if len(event["result"]["hypotheses"]) > 0 and event["result"]["final"]:
                    if len(self.final_hyp) > 0:
                        self.final_hyp += " "
                    self.final_hyp += event["result"]["hypotheses"][0]["transcript"]
            except:
                e = sys.exc_info()[0]
                logger.warn(
                    "Failed to extract hypothesis from recognition result:" + e)
        elif event["status"] != 0:
            self.error_status = event["status"]
            self.error_message = event.get("message", "")

    def close(self):
        logger.info("%s: Receiving 'close' from worker" % (self.id))
        self.final_result_queue.put(self.final_hyp)


class ReferenceHandler(tornado.web.RequestHandler):
    def post(self, *args, **kwargs):
        content_id = self.request.headers.get("Content-Id")
        if content_id:
            content = codecs.decode(self.request.body, "utf-8")
            user_id = self.request.headers.get("User-Id", "")
            self.application.save_reference(content_id, dict(
                content=content, user_id=user_id, time=time.strftime("%Y-%m-%dT%H:%M:%S")))
            logger.info("Received reference text for content %s and user %s" % (
                content_id, user_id))
            self.set_header('Access-Control-Allow-Origin', '*')
        else:
            self.set_status(400)
            self.finish("No Content-Id specified")

    def options(self, *args, **kwargs):
        self.set_header('Access-Control-Allow-Origin', '*')
        self.set_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        self.set_header('Access-Control-Max-Age', 1000)
        # note that '*' is not valid for Access-Control-Allow-Headers
        self.set_header('Access-Control-Allow-Headers',
                        'origin, x-csrftoken, content-type, accept, User-Id, Content-Id')


class StatusSocketHandler(tornado.websocket.WebSocketHandler):
    # needed for Tornado 4.0
    def check_origin(self, origin):
        return True

    def open(self):
        logger.info("New status listener")
        self.application.status_listeners.add(self)
        self.application.send_status_update_single(self)

    def on_close(self):
        logger.info("Status listener left")
        self.application.status_listeners.remove(self)


class WorkerSocketHandler(tornado.websocket.WebSocketHandler):
    def __init__(self, application, request, **kwargs):
        tornado.websocket.WebSocketHandler.__init__(
            self, application, request, **kwargs)
        self.client_socket = None

    # needed for Tornado 4.0
    def check_origin(self, origin):
        return True

    def open(self):
        self.client_socket = None

        try:
            self.application.available_workers[self.get_argument(
                "model", "none", True)].add(self)
        except KeyError:
            self.application.available_workers[self.get_argument("model", "none", True)] = {
                self}

        logger.info("New " + self.get_argument("model", "none", True) + " worker is available: " + self.__str__() )
        logger.info("Available workers: " +  str(self.application.available_workers))
        logger.info("Number of worker available (worker) " + str(len(self.application.available_workers)))

        self.application.send_status_update()

    def on_close(self):
        logger.info("Worker " + self.__str__() + " leaving")
        self.application.available_workers[self.get_argument(
            "model", "none", True)].discard(self)

        if self.client_socket:
            self.client_socket.close()

        self.application.send_status_update()

    def on_message(self, message):
        assert self.client_socket is not None
        event = json.loads(message)
        self.client_socket.send_event(event)

    def set_client_socket(self, client_socket):
        self.client_socket = client_socket


class DecoderSocketHandler(tornado.websocket.WebSocketHandler):
    # needed for Tornado 4.0
    def check_origin(self, origin):
        return True

    def send_event(self, event):
        event["id"] = self.id
        event_str = str(event)
        if len(event_str) > 100:
            event_str = event_str[:97] + "..."
        logger.info("%s: Sending event %s to client" % (self.id, event_str))
        self.write_message(json.dumps(event))

    def open(self):
        self.id = str(uuid.uuid4())
        logger.info("%s: OPEN" % (self.id))
        logger.info("%s: Request arguments: %s" % (self.id, " ".join(
            ["%s=\"%s\"" % (a, self.get_argument(a)) for a in self.request.arguments])))
        self.user_id = self.get_argument("user-id", "none", True)
        self.content_id = self.get_argument("content-id", "none", True)
        self.worker = None

        # for Prometheus monitoring
        num_worker.set(len(self.application.available_workers))
        num_req.inc(1)
        model = self.get_argument("model", "UNKNOWN_MODEL", True)
        logger.info("client with ws requested model: " + str(model))

        try:
            logger.info("self.application.available_workers: " + str(self.application.available_workers))
            spawn_worker = (model not in list(self.application.available_workers.keys())) or len(
                self.application.available_workers[model]) <= 0
            
            if spawn_worker:
                logger.info("Start spawning a new worker")
                SpawnWorker(model=model).start()

            self.worker = self.application.available_workers[model].pop()

            self.application.send_status_update()
            logger.info("%s: Using worker %s" % (self.id, self.__str__()))
            self.worker.set_client_socket(self)

            content_type = self.get_argument("content-type", None, True)
            if content_type:
                logger.info("%s: Using content type: %s" % (self.id, content_type))

            self.worker.write_message(json.dumps(dict(
                id=self.id, content_type=content_type, user_id=self.user_id, content_id=self.content_id, model=model)))
        except KeyError:
            logger.warning("%s: No worker available for client request" % self.id)
            event = dict(status=common.STATUS_NOT_AVAILABLE,
                         message="No decoder available, try again 60 seconds later")
            num_req_reject.inc(1)
            logger.info("Number of requests processed: " + str(self.application.num_requests_processed))

            self.send_event(event)
            self.close()

    def on_connection_close(self):
        logger.info("%s: Handling on_connection_close()" % self.id)
        self.application.num_requests_processed += 1
        self.application.send_status_update()
        if self.worker:
            try:
                self.worker.set_client_socket(None)
                logger.info("%s: Closing worker connection" % self.id)
                self.worker.close()
            except:
                pass

    def on_message(self, message):
        assert self.worker is not None
        logger.info("%s: Forwarding client message (%s) of length %d to worker" % (
            self.id, type(message), len(message)))
        # for python 2
        # if isinstance(message, unicode):
        # for python 3
        if isinstance(message, str):
            self.worker.write_message(message, binary=False)
        else:
            self.worker.write_message(message, binary=True)


def main():
    logging.basicConfig(level=logging.DEBUG,
                        format="%(levelname)8s %(asctime)s %(message)s ")
    logging.debug('Starting up server')
    from tornado.options import define, options
    define("certfile", default="",
           help="certificate file for secured SSL connection")
    define("keyfile", default="", help="key file for secured SSL connection")

    tornado.options.parse_command_line()
    app = Application()
    if options.certfile and options.keyfile:
        ssl_options = {
            "certfile": options.certfile,
            "keyfile": options.keyfile,
        }

        logging.info("Using SSL for serving requests")
        app.listen(options.port, ssl_options=ssl_options)
    else:
        # non root can't run port above 1024
        app.listen(8080).start()
    prom.start_http_server(8081)
    tornado.ioloop.IOLoop.instance().start()


if __name__ == "__main__":
    main()
