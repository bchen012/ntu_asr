import schedule, time, subprocess, logging

def spawn_job_eight_am():
    logging.info("Send 55 requests to the cluster")
    subprocess.Popen(['bash', 'client/send_requests.sh', '55']) #55

def spawn_job_nine_am():
    logging.info("Send 130 requests to the cluster")
    subprocess.Popen(['bash', 'client/send_requests.sh', '130']) #130

def spawn_job_ten_am():
    logging.info("Send 153 requests to the cluster")
    subprocess.Popen(['bash', 'client/send_requests.sh', '153']) #153

def spawn_job_eleven_am():
    logging.info("Send 160 requests to the cluster")
    subprocess.Popen(['bash', 'client/send_requests.sh', '160']) #160

def spawn_job_twelve_am():
    logging.info("Send 146 requests to the cluster")
    subprocess.Popen(['bash', 'client/send_requests.sh', '146']) #146

def spawn_job_one_pm():
    logging.info("Send 136 requests to the cluster")
    subprocess.Popen(['bash', 'client/send_requests.sh', '136']) #136

def spawn_job_two_pm():
    logging.info("Send 150 requests to the cluster")
    subprocess.Popen(['bash', 'client/send_requests.sh', '150']) #150

def spawn_job_four_pm():
    logging.info("Send 145 requests to the cluster")
    subprocess.Popen(['bash', 'client/send_requests.sh', '145']) #145

def spawn_job_five_pm():
    logging.info("Send 110 requests to the cluster")
    subprocess.Popen(['bash', 'client/send_requests.sh', '110']) #110

def spawn_job_six_pm():
    logging.info("Send 45 requests to the cluster")
    subprocess.Popen(['bash', 'client/send_requests.sh', '45']) #45

def spawn_job_three_pm():
    logging.info("Send 150 requests to the cluster")
    subprocess.Popen(['bash', 'client/send_requests.sh', '150']) #150

# https://savvytime.com/converter/sgt-to-utc
# SGT 3am = UCT 7pm
# for debug : schedule.every(1).minutes.do(job)

#  Send requests at 8am
schedule.every().day.at('08:00').do(spawn_job_eight_am)
#  Send requests at 9am
schedule.every().day.at('09:00').do(spawn_job_nine_am)
#  Send requests at 10am
schedule.every().day.at('10:00').do(spawn_job_ten_am)
#  Send requests at 11am
schedule.every().day.at('11:00').do(spawn_job_eleven_am)
#  Send requests at 12pm
schedule.every().day.at('12:00').do(spawn_job_twelve_am)
#  Send requests at 1pm
schedule.every().day.at('13:00').do(spawn_job_one_pm)
#  Send requests at 2pm
schedule.every().day.at('14:00').do(spawn_job_two_pm)
#  Send requests at 3pm
schedule.every().day.at('15:00').do(spawn_job_three_pm)
#  Send requests at 4pm
schedule.every().day.at('16:00').do(spawn_job_four_pm)
#  Send requests at 5pm
schedule.every().day.at('17:00').do(spawn_job_five_pm)
#  Send requests at 6pm
schedule.every().day.at('18:00').do(spawn_job_six_pm)


while True:
    schedule.run_pending()
    time.sleep(1)
