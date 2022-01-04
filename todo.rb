require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'
require 'puma'
require 'pry'

configure do
  enable :sessions
  set :erb, escape_html: true
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

helpers do
  def list_completed?(list)
    todos_count(list).positive? && todos_left(list).zero?
  end

  def todos_left(list)
    list[:todos].count { |todo| todo[:completed] == false }
  end

  def todos_count(list)
    list[:todos].size
  end

  def sort_lists(lists, &block)
    incomplete_lists, complete_lists = lists.partition do |list|
      !list_completed?(list)
    end

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sort_todos(todos, &block)
    incomplete_todos, complete_todos = todos.partition { |todo| !todo[:completed] }

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end

  def list_class(list)
    'complete' if list_completed?(list)
  end
end

# Return error message if list name is invalid. Return nil if valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'List names must be between 1 and 100 characters long'
  elsif session[:lists].any? { |list| list[:name] == name }
    'That todo list name already exists'
  end
end

def error_for_todo(todo)
  return if (1..200).cover?(todo.size)

  'Todos must be between 1 and 200 characters long'
end

def valid_id?(id)
  (id.to_i.to_s == id) && (0...session[:lists].count).cover?(id.to_i)
end

def load_list(index)
  if session[:lists].map { |list| list[:id] }.include?(index)
    list = session[:lists].find { |lst| lst[:id] == index }
    return list
  end

  session[:error] = 'The specified list was not found.'
  redirect '/lists'
end

def find_todo_id(todos)
  todo_id = 0
  todos.each_with_index do |todo, i|
    todo_id = i if todo[:id] == params[:todo_id].to_i
  end
  todo_id
end

def next_list_id(lists)
  max = lists.map { |list| list[:id] }.max || 0
  max + 1
end

get '/' do
  redirect '/lists'
end

# view lists of lists
get '/lists' do
  @lists = session[:lists]
  binding.pry
  erb :lists, layout: :layout
end

# render new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_list_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = 'New list added'
    redirect '/lists'
  end
end

# edit name of a todo list
post '/lists/:list_id' do
  list_name = params[:list_name].strip

  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  error = @list[:name] == list_name ? nil : error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = params['list_name']
    session[:success] = 'List name updated'
    redirect '/lists'
  end
end

get '/lists/:list_id/edit' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  erb :edit_list, layout: :layout
end

post '/lists/:list_id/delete' do
  @list_id = params[:list_id].to_i
  session[:lists].reject! { |list| list[:id] == @list_id }
  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    '/lists'
  else
    session[:success] = 'The list has been deleted'
    redirect '/lists'
  end
end

get '/lists/:list_id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  erb :list, layout: :layout
end

def next_todo_id(todos)
  max = todos.map { |todo| todo[:id] }.max || 0
  max + 1
end

post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo = params[:todo].strip
  error = error_for_todo(todo)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_todo_id(@list[:todos])
    @list[:todos] << { id: id, name: params['todo'], completed: false }
    session[:success] = 'Todo added'
    redirect "/lists/#{@list_id}"
  end
end

post '/lists/:list_id/todos/:todo_id/delete' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  @list[:todos].reject! { |todo| todo[:id] == todo_id }

  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    status 204
  else
    session[:success] = 'Todo deleted'
    redirect "lists/#{@list_id}"
  end
end

post '/lists/:list_id/todos/:todo_id/toggle' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = find_todo_id(@list[:todos])

  @list[:todos][todo_id][:completed] = (params[:completed] == 'true')
  session[:success] = 'The todo has been updated'
  redirect "lists/#{@list_id}"
end

post '/lists/:list_id/todos/complete' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  if !@list[:todos].empty?
    @list[:todos].each { |todo| todo[:completed] = true }
    session[:success] = 'All todos have been updated'
  else
    session[:error] = 'No todos to complete'
  end

  redirect "lists/#{@list_id}"
end
