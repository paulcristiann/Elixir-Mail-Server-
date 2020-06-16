defmodule MailServer do
  require Logger

  def start() do
    port = String.to_integer(System.get_env("PORT") || "6969")

    children = [
      {Task.Supervisor, name: MailServer.TaskSupervisor},
      {Task, fn -> MailServer.accept(port) end}
    ]

    opts = [strategy: :one_for_one, name: MailServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def accept(port) do
    {:ok, socket} = :gen_tcp.listen(port,
                      [:binary, packet: :line, active: false, reuseaddr: true])
    Logger.info "Started web server on port #{port}"
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(MailServer.TaskSupervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  defp serve(socket) do
    socket
    |> read_line()
    |> parse_line(socket)

    serve(socket)
  end

  defp read_line(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    data
  end

  defp parse_line(line, socket) do
    case String.split(line) do
      ["CREATE_ACCOUNT", username, password] -> 
        case File.read("accounts.txt") do
          {:ok, content} -> 
            #Check if username is taken
            if String.contains?(content, username) do
              :gen_tcp.send(socket, "Username already taken\r\n")
            else
              new_content = "#{content}\n#{username} #{password}"
              File.write("accounts.txt", new_content)
              File.write("#{username}.txt", "")
              :gen_tcp.send(socket, "OK\r\n")
            end
          {:error, exception} -> :gen_tcp.send(socket, "ERROR Internal Server Error - #{exception}\r\n")
        end
      
      ["LOGIN", username, password] ->
        #Return user token if not already logged in
        case File.read("tokens.txt") do
          {:ok, tokens_content} -> 
            #Check if username is currently logged
            if String.contains?(tokens_content, username) do
              :gen_tcp.send(socket, "ERROR Username already logged on\r\n")
            else
              #Check password
              case File.read("accounts.txt") do
                {:ok, accounts_content} -> 
                  #Check credentials
                  user_credentials_list = String.split(accounts_content, "\n")
                  #Reduce to a map of users:pass
                  user_map = Enum.reduce(user_credentials_list, %{}, fn(line, result) ->
                    String.split(line, " ")
                    |> (fn(x) -> Map.put(result, hd(x), List.last(x)) end).()
                    end)
                  #Check if user:pass is correct
                  case Map.fetch(user_map, username) do
                    {:ok, stored_pass} -> 
                      if stored_pass == password do
                        #Generate a token
                        token = gen_reference()
                        :gen_tcp.send(socket, "OK #{token}\r\n")
                        new_content = "#{tokens_content}\n#{token} #{username}"
                        File.write("tokens.txt", new_content)
                      else
                        :gen_tcp.send(socket, "ERROR Invalid password\r\n")
                    end
                    :error -> :gen_tcp.send(socket, "ERROR Invalid login\r\n")
                  end
                {:error, exception} -> :gen_tcp.send(socket, "ERROR Internal Server Error - #{exception}\r\n")
              end
            end
          {:error, exception} -> :gen_tcp.send(socket, "ERROR Internal Server Error - #{exception}\r\n")
        end

      ["LOGOUT", token] ->
        case File.read("tokens.txt") do
          {:ok, tokens_content} ->
            user_tokens_list = String.split(tokens_content, "\n")
            user_tokens_map = Enum.reduce(user_tokens_list, %{}, fn(line, result) ->
              String.split(line, " ")
              |> (fn(x) -> Map.put(result, hd(x), List.last(x)) end).()
              end)
            case Map.fetch(user_tokens_map, token) do
              {:ok, username} -> 
                :gen_tcp.send(socket, "OK Logged out #{username}\r\n")
                updated_map = Map.delete(user_tokens_map, token)
                updated_list = Enum.map(updated_map, fn {k,v} -> "#{k} #{v}" end)
                updated_content = Enum.join(updated_list, "\n")
                File.write("tokens.txt", updated_content)
              :error -> :gen_tcp.send(socket, "ERROR Invalid token\r\n")
              end
          {:error, exception} -> :gen_tcp.send(socket, "ERROR Internal Server Error - #{exception}\r\n")
        end
        

      ["SEND", user_list, message, token] -> 
        case File.read("tokens.txt") do
          {:ok, tokens_content} ->
            user_tokens_list = String.split(tokens_content, "\n")
            user_tokens_map = Enum.reduce(user_tokens_list, %{}, fn(line, result) ->
              String.split(line, " ")
              |> (fn(x) -> Map.put(result, hd(x), List.last(x)) end).()
              end)
            case Map.fetch(user_tokens_map, token) do
              {:ok, sender} -> 
                #Generate a message id
                message_id = gen_reference()
                #Send the message to all the users in the list
                list = String.split(user_list, ",")
                Enum.each(list, fn x -> 
                  {:ok, mailbox_content} = File.read("#{x}.txt")
                  File.write("#{x}.txt", "#{mailbox_content}\n#{message_id} #{sender}:#{message}") end)
                  :gen_tcp.send(socket, "OK\r\n")
              :error -> :gen_tcp.send(socket, "ERROR Invalid token\r\n")
            end
          {:error, exception} -> :gen_tcp.send(socket, "ERROR Internal Server Error - #{exception}\r\n")
        end

      ["READ_MAILBOX", token] -> 
        case File.read("tokens.txt") do
          {:ok, tokens_content} ->
            user_tokens_list = String.split(tokens_content, "\n")
            user_tokens_map = Enum.reduce(user_tokens_list, %{}, fn(line, result) ->
              String.split(line, " ")
              |> (fn(x) -> Map.put(result, hd(x), List.last(x)) end).()
              end)
            case Map.fetch(user_tokens_map, token) do
              {:ok, user} -> 
                {:ok, mailbox_content} = File.read("#{user}.txt")
                user_emails_list = String.split(mailbox_content, "\n")
                user_emails_map = Enum.reduce(user_emails_list, %{}, fn(line, result) ->
                  String.split(line, " ")
                  |> (fn(x) -> Map.put(result, hd(x), List.last(x)) end).()
                  end)
                :gen_tcp.send(socket, "OK #{Enum.map(user_emails_map, fn {k,_} -> "#{k} " end)}\r\n")
              :error -> :gen_tcp.send(socket, "ERROR Invalid token\r\n")
            end
          {:error, exception} -> :gen_tcp.send(socket, "ERROR Internal Server Error - #{exception}\r\n")
        end

      ["READ_MSG", id, token] -> 
        case File.read("tokens.txt") do
          {:ok, tokens_content} ->
            user_tokens_list = String.split(tokens_content, "\n")
            user_tokens_map = Enum.reduce(user_tokens_list, %{}, fn(line, result) ->
              String.split(line, " ")
              |> (fn(x) -> Map.put(result, hd(x), List.last(x)) end).()
              end)
            case Map.fetch(user_tokens_map, token) do
              {:ok, user} -> 
                {:ok, mailbox_content} = File.read("#{user}.txt")
                user_emails_list = String.split(mailbox_content, "\n")
                user_emails_map = Enum.reduce(user_emails_list, %{}, fn(line, result) ->
                  String.split(line, " ")
                  |> (fn(x) -> Map.put(result, hd(x), List.last(x)) end).()
                  end)
                case Map.fetch(user_emails_map, id) do
                  {:ok, email_body} ->
                    :gen_tcp.send(socket, "OK #{email_body}\r\n")
                  :error -> :gen_tcp.send(socket, "ERROR Message not found\r\n")
                  end
              :error -> :gen_tcp.send(socket, "ERROR Invalid token\r\n")
            end
          {:error, exception} -> :gen_tcp.send(socket, "ERROR Internal Server Error - #{exception}\r\n")
        end
      _ -> :gen_tcp.send(socket, "ERROR Unknown request\r\n")
    end
  end

  def gen_reference() do
    min = String.to_integer("100000", 36)
    max = String.to_integer("ZZZZZZ", 36)
  
    max
    |> Kernel.-(min)
    |> :rand.uniform()
    |> Kernel.+(min)
    |> Integer.to_string(36)
  end
end