import java.io.*;
import java.net.Socket;
import java.net.UnknownHostException;

public class ServerManager {
    public static String SendRequest(String command){

        String hostname = "localhost";
        int port = 6969;

        try (Socket socket = new Socket(hostname, port)) {

            OutputStream output = socket.getOutputStream();
            PrintWriter writer = new PrintWriter(output, true);
            writer.println(command);

            InputStream input = socket.getInputStream();

            BufferedReader reader = new BufferedReader(new InputStreamReader(input));

            String response = reader.readLine();

            //System.out.println("Server responded with " + response);
            return response;

        } catch (UnknownHostException ex) {

            System.out.println("Server not found: " + ex.getMessage());
            return null;

        } catch (IOException ex) {

            System.out.println("I/O error: " + ex.getMessage());
            return null;
        }
    }
}
