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