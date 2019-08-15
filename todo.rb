require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

helpers do
  # Returns boolean referencing list completeness.
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list).zero?
  end

  # Returns class for list.
  def list_class(list)
    "complete" if list_complete?(list)
  end

  # Returns class for todo
  def todo_class(todo)
    "complete" if todo[:completed]
  end

  # Returns total todos in a list
  def todos_count(list)
    list[:todos].size
  end

  # Returns count of completed todos in a list
  def todos_remaining_count(list)
    list[:todos].count { |todo| todo[:completed] == false }
  end

  # Sorts completed lists to the bottom
  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }

    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end

  # Sorts completed todos to the bottom
  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end
end

class SessionPersistence
  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def find_list(id)
    @session[:lists].find { |list| list[:id] == id }
  end

  def all_lists
    @session[:lists]
  end

  def create_new_list(list_name)
    new_id = next_id(@session[:lists])
    @session[:lists] << { id: new_id, name: list_name, todos: [] }
  end

  def delete_list(id)
    @session[:lists].reject! { |list| list[:id] == id }
  end

  def update_list_name(list_name, list_id)
    list = find_list(list_id)
    list[:name] = list_name
  end

  def create_new_todo(list_id, todo_name)
    list = find_list(list_id)
    new_id = next_id(list[:todos])
    list[:todos] << {id: new_id, name: todo_name, completed: false}
  end

  def delete_todo(list_id, todo_id)
    list = find_list(list_id)
    list[:todos].reject! { |todo| todo[:id] == todo_id }
  end

  def update_todo_status(list_id, todo_id, new_status)
    list = find_list(list_id)
    todo = list[:todos].find { |t| t[:id] == todo_id }
    todo[:completed] = new_status
  end

  def mark_all_todos_complete(list_id)
    list = find_list(list_id)
    list[:todos].each { |todo| todo[:completed] = true }
  end

  private

  def next_id(collection)
    max = collection.map { |element| element[:id] }.max || 0
    max + 1
  end
end

def load_list(id)
  list = @storage.find_list(id)
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "List name must be between 1 and 100 characters."
  elsif @storage.all_lists.any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_todo_name(name)
  if !(1..100).cover?(name.size)
    "Todo must be between 1 and 100 characters."
  end
end

before do
  @storage = SessionPersistence.new(session)
end

get "/" do
  redirect "/lists"
end

# View all of the lists
get "/lists" do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Render the edit list name form
get "/lists/:listid/edit" do
  list_id = params[:listid].to_i
  @list = load_list(list_id)
  erb :edit_list, layout: :layout
end

# View specific list
get "/lists/:listid" do
  list_id = params[:listid].to_i
  @list = load_list(list_id)
  erb :individual_list
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list
  else
    @storage.create_new_list(list_name)
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# Edits a list
post "/lists/:listid/edit" do
  id = params[:listid].to_i

  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list
  else
    @storage.update_list_name(list_name, id)
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

# Deletes a list
post "/lists/:listid/delete" do
  id = params[:listid].to_i
  @storage.delete_list(id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

# Adds todo items to a list
post "/lists/:listid/todos" do
  list_id = params[:listid].to_i
  @list = load_list(list_id)

  todo_name = params[:todo].strip
  error = error_for_todo_name(todo_name)
  if error
    session[:error] = error
    erb :individual_list
  else
    @storage.create_new_todo(list_id, todo_name)
    session[:success] = "The todo was added."
    redirect "lists/#{list_id}"
  end
end

# Deletes todo items from a list
post "/lists/:listid/todos/:todoid/delete" do
  list_id = params[:listid].to_i
  todo_id = params[:todoid].to_i

  @storage.delete_todo(list_id, todo_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{list_id}"
  end
end

# Marks todo items as complete/incomplete
post "/lists/:listid/todos/:todoid/complete" do
  list_id = params[:listid].to_i
  todo_id = params[:todoid].to_i

  is_completed = params[:completed] == "true"
  @storage.update_todo_status(list_id, todo_id, is_completed)

  session[:success] = "The todo has been updated."
  redirect "/lists/#{list_id}"
end

# Completes all todo items
post "/lists/:listid/todos/complete_all" do
  list_id = params[:listid].to_i

  @storage.mark_all_todos_complete(list_id)

  session[:success] = "All todos have been updated."
  redirect "/lists/#{list_id}"
end