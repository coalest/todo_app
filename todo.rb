require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubis'
require 'pry'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

helpers do
  def list_completed?(list)
    todos_count(list) > 0 && todos_left(list) == 0 
  end

  def todos_left(list)
    list[:todos].count { |todo| todo[:completed] == false }
  end

  def todos_count(list)
    list[:todos].size
  end

  def sort_lists(lists, &block)
    incomplete_lists = {}
    complete_lists = {}

    lists.each_with_index do |list, index|
      if list_completed?(list)
        complete_lists[index] = list
      else
        incomplete_lists[index] = list
      end
    end
    incomplete_lists.each { |id, list| yield list, id }
    complete_lists.each { |id, list| yield list, id }
  end

  def sort_todos(todos, &block)
    incomplete_todos = {}
    complete_todos = {}

    todos.each_with_index do |todo, index|
      if todo[:completed]
        complete_todos[todo] = index
      else
        incomplete_todos[todo] = index
      end
    end

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end

  def list_class(list)
    "complete" if list_completed?(@list)
  end
end

# Return error message if list name is invalid. Return nil if valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'List names must be between 1 and 100 characters long'
   elsif other_lists(name).any? { |list| list[:name] == name }
     'That todo list name already exists'
  end
end

def error_for_todo(todo)
  if !(1..200).cover? todo.size
    'Todos must be between 1 and 200 characters long'
  end
end

def valid_id?(id)
  (id.to_i.to_s == id) && (0...session[:lists].count).cover?(id.to_i)
end

def other_lists(name)
  return [] unless params[:list_id]
  current_list_name = session[:lists][params[:list_id].to_i][:name] 
  session[:lists].reject { |list| current_list_name == name} 
end

get "/" do
  redirect "/lists"
end

# view lists of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# render new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'New list added'
    redirect "/lists"
  end
end

post "/lists/:list_id" do
  list_name = params[:list_name].strip
  not_found unless valid_id?(params[:list_id])

  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = params["list_name"]
    session[:success] = 'List name changed'
    redirect "/lists"
  end
end

get "/lists/:list_id/edit" do
  not_found unless valid_id?(params[:list_id])
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  erb :edit_list, layout: :layout
end

post "/lists/:list_id/delete" do
  @list_id = params[:list_id].to_i
  session[:lists].delete_at(@list_id)
  session[:success] = 'The list has been deleted'

  redirect "/lists"
end

get "/lists/:list_id" do
  not_found unless valid_id?(params[:list_id])
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id] 
  erb :list, layout: :layout
end

post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id] 


  todo = params[:todo].strip
  error = error_for_todo(todo)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: params["todo"], completed: false }
    session[:success] = "Todo added"
    redirect "/lists/#{@list_id}"
  end
end

post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id] 
  todo_id = params[:todo_id].to_i

  @list[:todos].delete_at(todo_id)
  session[:success] = "Todo deleted"
  redirect "lists/#{@list_id}"
end

post "/lists/:list_id/todos/:todo_id/toggle" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id] 
  todo_id = params[:todo_id].to_i

  @list[:todos][todo_id][:completed] = (params[:completed] == "true")
  session[:success] = "The todo has been updated"
  redirect "lists/#{@list_id}"
end

post "/lists/:list_id/todos/complete" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id] 
  
  if @list[:todos].size > 0
    @list[:todos].each { |todo| todo[:completed] = true }
    session[:success] = "All todos have been updated"
  else
    session[:error] = "No todos to complete"
  end

  redirect "lists/#{@list_id}"
end
