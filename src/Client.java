import java.io.*;
import java.net.Socket;
import java.net.UnknownHostException;
import java.util.Scanner;

public class Client {

    public static Integer total_email_count = 0;

    public static void main(String[] args) throws IOException {

        //Check login status
        try {
            File session = new File("session.txt");
            Scanner myReader = new Scanner(session);
            String session_data = "";
            while (myReader.hasNextLine()) {
                session_data = myReader.nextLine();
            }
            myReader.close();
            Client.loop(session_data);
        } catch (FileNotFoundException e) {
            //The User is not logged in - try login
            Scanner scanner = new Scanner( System.in);
            System.out.println("=============================");
            System.out.println("username:");
            String username = scanner.nextLine();
            System.out.println("password:");
            String password = scanner.nextLine();
            System.out.println("=============================");
            String response = ServerManager.SendRequest("LOGIN " + username + " " + password);
            String[] tokens = response.split(" ");
            if(tokens[0].equals("OK")){
                //Create session file
                File session = new File("session.txt");
                session.createNewFile();
                FileWriter myWriter = new FileWriter("session.txt");
                myWriter.write(tokens[1]);
                myWriter.close();
                Client.loop(tokens[1]);
            }else{
                System.out.println(response);
                return;
            }
        }

    }
    public static void loop(String session){

        System.out.println("Logged in with session id: " + session);

        //Fetch number of emails
        new Thread(() -> {
            String response = ServerManager.SendRequest("READ_MAILBOX " + session);
            String[] tokens = response.split(" ");
            if(tokens[0].equals("OK")){
                total_email_count = tokens.length - 1;
            }else{
                System.out.println("Errors getting emails");
                return;
            }
        }).start();

        while(true){

            System.out.println("Emails: " + total_email_count);

            //Accept commands and run them async
            Scanner scanner = new Scanner(System.in);
            System.out.print("Command> ");
            String command = scanner.nextLine();
            String[] tokens = command.split(" ");
            String type = tokens[0];

            switch(type) {
                case "LOGOUT":
                    //Delete local session file
                    File f = new File("session.txt");
                    f.delete();
                    //Send request to server
                    String response = ServerManager.SendRequest("LOGOUT " + session);
                    String[] t = response.split(" ");
                    if(t[0].equals("OK")){
                        System.out.println("Logged out");
                    }else{
                        System.out.println("Error logging out");
                    }
                    return;
                case "SEND":
                    //Send request to server
                    String response2 = ServerManager.SendRequest(command + " " + session);
                    String[] t2 = response2.split(" ");
                    if(t2[0].equals("OK")){
                        System.out.println("Message sent");
                    }else{
                        System.out.println("Error sending message");
                    }
                    break;
                case "READ_MAILBOX":
                    //Send request to server
                    String response3 = ServerManager.SendRequest(command + " " + session);
                    String[] t3 = response3.split(" ");
                    if(t3[0].equals("OK")){
                        System.out.println(response3);
                    }else{
                        System.out.println("Error reading mailbox");
                    }
                    break;
                case "READ_MSG":
                    //Send request to server
                    String response4 = ServerManager.SendRequest(command + " " + session);
                    String[] t4 = response4.split(" ");
                    if(t4[0].equals("OK")){
                        System.out.println(response4);
                    }else{
                        System.out.println("Error reading message");
                    }
                    break;
                default:
                    System.out.println("Unknown command");
            }
        }
    }

}
