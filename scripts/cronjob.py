import schedule, time, subprocess, logging

flexanswer_uat=5
eight_am_jobs=55
nine_am_jobs=130
ten_am_jobs=140
eleven_am_jobs=140
twelve_pm_jobs=140
one_pm_jobs=140
two_pm_jobs=140
three_pm_jobs=140
four_pm_jobs=140
five_pm_jobs=140
six_pm_jobs=110
seven_pm_jobs=2
eight_pm_jobs=2
nine_pm_jobs=2
ten_pm_jobs=2
eleven_pm_jobs=2
twelve_am_jobs=2
one_am_jobs=2
two_am_job=1
three_am_jobs=3
four_am_jobs=1
five_am_jobs=2
six_am_jobs=1
seven_am_jobs=2

def clean_job():
    logging.info("Checking completed jobs and delete them")
    subprocess.Popen(['bash', '/home/appuser/opt/cronjob_delete_kubernetes_jobs.sh'])  #async

def scale_jobs(number_workers):
    logging.info("Scale new workers")
    subprocess.Popen(['bash', '/home/appuser/opt/cronjob_spawn_kubernetes_jobs.sh', str(number_workers)]) #55

def scale_job_eight_am():
    #scale_jobs(eight_am_jobs)
    scale_jobs(flexanswer_uat)

def scale_job_nine_am():
    scale_jobs(nine_am_jobs)

def scale_job_ten_am():
    scale_jobs(ten_am_jobs)

def scale_job_eleven_am():
    scale_jobs(eleven_am_jobs)
    
def scale_job_twelve_pm():
    scale_jobs(twelve_pm_jobs)

def scale_job_one_pm():
    scale_jobs(one_pm_jobs)

def scale_job_two_pm():
    scale_jobs(two_pm_jobs)

def scale_job_three_pm():
    scale_jobs(three_pm_jobs)

def scale_job_four_pm():
    scale_jobs(four_pm_jobs)

def scale_job_five_pm():
    scale_jobs(five_pm_jobs)
        
def scale_job_six_pm():
    scale_jobs(six_pm_jobs)

def scale_job_seven_pm():
    scale_jobs(seven_pm_jobs)

def scale_job_eight_pm():
    scale_jobs(eight_pm_jobs)

def scale_job_nine_pm():
    scale_jobs(nine_pm_jobs)

def scale_job_ten_pm():
    scale_jobs(ten_pm_jobs)

def scale_job_eleven_pm():
    scale_jobs(eleven_pm_jobs)

def scale_job_twelve_am():
    scale_jobs(twelve_am_jobs)

def scale_job_one_am():
    scale_jobs(one_am_jobs)

def scale_job_two_am():
    scale_jobs(two_am_job)

def scale_job_three_am():
    scale_jobs(three_am_jobs)

def scale_job_four_am():
    scale_jobs(four_am_jobs)

def scale_job_five_am():
    scale_jobs(five_am_jobs)

def scale_job_six_am():
    scale_jobs(six_am_jobs)

def scale_job_seven_am():
    scale_jobs(seven_am_jobs)


# https://savvytime.com/converter/sgt-to-utc
# SGT 3am = UCT 7pm 
# for debug : schedule.every(1).minutes.do(job)

# Prepare jobs for 8am - 12:00am 
# UTC: schedule.every().day.at('23:40').do(scale_job_eight_am)
schedule.every().day.at('07:30').do(scale_job_eight_am)
# Prepare jobs for 9am - 01:00am
#schedule.every().day.at('08:30').do(scale_job_nine_am)
# jobs for 10am - 02:00am
#schedule.every().day.at('09:30').do(scale_job_ten_am)
# Prepare jobs for 11am - 03am
#schedule.every().day.at('10:30').do(scale_job_eleven_am)
# jobs for 12pm - 04am
#schedule.every().day.at('11:30').do(scale_job_twelve_pm)
# Prepare jobs for 13pm
#schedule.every().day.at('12:30').do(scale_job_one_pm)
# Jobs for 14pm
#schedule.every().day.at('13:30').do(scale_job_two_pm)
# Jobs for 15pm
#schedule.every().day.at('14:30').do(scale_job_three_pm)
# Jobs for 16pm
#schedule.every().day.at('15:30').do(scale_job_four_pm)
# Jobs for 17pm
#schedule.every().day.at('16:30').do(scale_job_five_pm)
# Jobs for 18pm
# Jobs for 18pm

#schedule.every().day.at('17:30').do(scale_job_six_pm)
# Jobs for 19pm
#schedule.every().day.at('18:30').do(scale_job_seven_pm)
# Jobs for 20pm
#schedule.every().day.at('19:30').do(scale_job_eight_pm)
# Jobs for 21pm
schedule.every().day.at('20:30').do(scale_job_nine_pm)
# Jobs for 22pm
#schedule.every().day.at('21:30').do(scale_job_ten_pm)
# Jobs for 23pm
#schedule.every().day.at('22:30').do(scale_job_eleven_pm)
# Jobs for 00am
#schedule.every().day.at('23:30').do(scale_job_twelve_am)
# Jobs for 01am
#schedule.every().day.at('00:30').do(scale_job_one_am)
# Jobs for 02am
#schedule.every().day.at('01:30').do(scale_job_two_am)
# Jobs for 03am
#schedule.every().day.at('02:30').do(scale_job_three_am)
# Jobs for 04am
#schedule.every().day.at('03:30').do(scale_job_four_am)
# jobs for 05am
#schedule.every().day.at('04:30').do(scale_job_five_am)
# Jobs for 06am
#schedule.every().day.at('05:30').do(scale_job_six_am)
# Jobs for 07am
#schedule.every().day.at('06:30').do(scale_job_seven_am)

#schedule.every().day.at('11:00').do(scale_down)
schedule.every().day.at("19:00").do(clean_job)


while True:
    schedule.run_pending()
    time.sleep(1)
