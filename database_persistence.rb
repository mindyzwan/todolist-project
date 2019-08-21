require "pg"

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
        PG.connect(ENV['DATABASE_URL'])
      else
        PG.connect(dbname: "todos")
      end
    @logger = logger
  end

  def disconnect
    @db.close
  end

  def query(statement, *params)
    @logger.info("#{statement}: #{params}")
    @db.exec_params(statement, params)
  end

  def load_todos(list_id)
    sql = "SELECT * FROM todos WHERE list_id = $1"
    results = query(sql, list_id)
    results.map do |tuple|
      { id: tuple["id"].to_i,
        name: tuple["name"],
        completed: tuple["completed"] == "t"}
    end
  end

  def find_list(id)
    sql = "SELECT * FROM lists WHERE id = $1"
    results = query(sql, id)
    tuple = results.first
    list_id = tuple["id"].to_i
    { id: list_id,
      name: tuple["name"],
      todos: load_todos(list_id)  }
  end

  def all_lists
    sql = "SELECT * FROM lists"
    results = query(sql)
    results.map do |tuple|
      list_id = tuple["id"].to_i
      { id: list_id,
        name: tuple["name"],
        todos: load_todos(list_id)  }
    end
  end

  def create_new_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1)"
    query(sql, list_name)
  end

  def delete_list(list_id)
    sql_1 = "DELETE FROM todos WHERE list_id = $1"
    sql_2 = "DELETE FROM lists WHERE id = $1"
    query(sql_1, list_id)
    query(sql_2, list_id)
  end

  def update_list_name(new_name, list_id)
    sql = "UPDATE lists SET name = $1 WHERE id = $2"
    query(sql, new_name, list_id)
  end

  def create_new_todo(list_id, todo_name)
    sql = "INSERT INTO todos (name, list_id) VALUES ($1, $2)"
    query(sql, todo_name, list_id)
  end

  def delete_todo(list_id, todo_id)
    sql = "DELETE FROM todos WHERE list_id = $1 AND id = $2"
    query(sql, list_id, todo_id)
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = "UPDATE todos SET completed = $1 WHERE list_id = $2 AND id = $3"
    query(sql, new_status, list_id, todo_id)
  end

  def mark_all_todos_complete(list_id)
    sql = "UPDATE todos SET completed = true WHERE list_id = $1"
    query(sql, list_id)
  end
end