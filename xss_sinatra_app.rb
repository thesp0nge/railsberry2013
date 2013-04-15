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
  session[:logged]="admin" if params["login"]=="admin" and params["password"]=="admin"
  erb :home if params["login"]=="admin" and params["password"]=="admin"
  @message = "Wrong password for 'admin' user" if params["login"] == "admin" and params["password"] != "admin"
  @message = "Unknown username #{params["login"]}" if params["login"] != "admin" and params["password"] != "admin"
  erb :login
end

get '/robots.txt' do
  headers "Content-Type"=>"text/plain"
  "User agent: *\nDisallow: /backend\nDisallow: /log\nDisallow: /db\nAllow: *\n"
end

get '/home' do
  if session[:logged].nil?
    @message="You must login first"
    erb :login
  end 
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
__END__

@@hello 

<!DOCTYPE html>

<html>
  <head>
    <meta charset="UTF-8">
    <title>Railsberry 2013 - broken app</title>
  </head>
  <body> 
    <h1>Railsberry 2013 - broken app</h1>
    <p>
      A very basic XSS vulnerable page
    </p>

    <p>
      Hello <%= @name %>
    </p>
  </body> 
</html>

@@login
<!DOCTYPE html>

<html>
  <head>
    <meta charset="UTF-8">
    <title>Railsberry 2013 - broken app</title>
  </head>
  <body>
    <h1>Railsberry 2013 - broken app</h1>
    <p>
      <%= @message %>
    </p>
    <form method="POST" action="/login">
      <input type="text" name="login" placeholder="put your login here">
      <input type="password" name="password" placeholder="and a password too">
      <input type="submit" value="login"/>
    </form>
    <p>
      <i>
        This authentication mechanism is broken since it gives too much
        information about what is wrong with user's secrets. A laconic "unknown
        username or password" would be a better choice.
      </i>
    </p>
    <p>
      <i>
        Moreover, there is also a XSS on the login parameter when you missed it
        since the value is replayed on the error message without filtering.
      </i>
    </p>
  </body>
</html>

@@home
<html>
  <head>
    <meta charset="UTF-8">
    <title>Railsberry 2013 - broken app</title>
  </head>
  <body>
    <h1>Railsberry 2013 - broken app</h1>
    <p>This is a completely broken web application used just for fun.</p>
  </body>
</html>

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
