require 'sinatra' 

configure do 
  enable :sessions
end

get '/logout' do
  session[:logged] = nil
  redirect '/login'
end

get '/users' do
  erb :users
end

get '/users/:name' do
  redirect '/home' unless params[:name] == 'tom' or params[:name] == 'mark' or params[:name]=='john'
  redirect "/hello?name=#{params[:name]}"

end

get '/hello' do
  if ! session[:logged]
    @message="You must login first"
    erb :login
  end 

  @name = params[:name]
  erb :hello
end

get '/login' do
  @message=""
  erb :login
end

post '/login' do

  ret = check_creds(params["login"], params["password"])


  if ret == 0
    session[:logged]=params["login"]
    redirect '/home'
  end

  @message = "Wrong password for #{params["login"]} user" if ret == 1
  @message = "Unknown username #{params["login"]}" if ret == -1
  erb :login
end

get '/robots.txt' do
  headers "Content-Type"=>"text/plain"
  "User agent: *\nDisallow: /backend\nDisallow: /log\nDisallow: /db\nAllow: *\n"
end

get '/home' do
  if session[:logged].nil?
    @message="You must login first"
    redirect '/login'
  end 
  erb :home
end

get '/backend' do

  erb :backend
end

get '/log' do
  if session[:logged].nil?
    @message="You must login first"
    redirect '/login'
  end 

  erb :log
end


get '/db' do
  if session[:logged].nil?
    @message="You must login first"
    redirect '/login'
  end 

  erb :db
end

def check_creds(username, password)
  ret = 0
  users = File.readlines('creds.txt')
  users.each do |u|
    u=u.chomp
    return 0 if u.split(':')[0] == username and u.split(':')[1] == password
    return 1 if u.split(':')[0] == username and u.split(':')[1] != password
  end

  return -1
end
__END__

@@log
<html>
  <head>
    <meta charset="UTF-8">
    <title>Railsberry 2013 - broken app</title>
  </head>
  <body>
    <h1>Railsberry 2013 - broken app</h1>
    <p>Logs here... but you're logged in... so you can browse me</p>
  </body>
</html>

@@db
<html>
  <head>
    <meta charset="UTF-8">
    <title>Railsberry 2013 - broken app</title>
  </head>
  <body>
    <h1>Railsberry 2013 - broken app</h1>
    <p>Databases here... but you're logged in... so you can browse me</p>
  </body>
</html>

@@backend
<html>
  <head>
    <meta charset="UTF-8">
    <title>Railsberry 2013 - broken app</title>
  </head>
  <body>
    <h1>Railsberry 2013 - broken app</h1>
    <p>
      The backend here... you can administer the site... adding posts... destroying databases... launching missiles... 
    </p>
      <% if session[:logged].nil? %>
      <p> wait a minute... you're not logged in... GOSH
      <% end %>

  </body>
</html>

@@users

<html>
  <head>
    <meta charset="UTF-8">
    <title>Railsberry 2013 - broken app</title>
  </head>
  <body>
    <h1>Railsberry 2013 - broken app</h1>
    <h2>Public list of users with an homepage:</h2>
    <ul>
      <li><a href="/users/tom">Tom</a></li>
      <li><a href="/users/mark">Mark</a></li>
      <li><a href="/users/john">John</a></li>
    </ul>

  </body>
</html>
