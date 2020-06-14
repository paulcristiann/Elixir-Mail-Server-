
## Elixir Email Server - ICLP HW

TCP Email Server coded in Elixir using Task and gen_tcp.

### Server specifications
Running by default on port 6969

 - `CREATE_ACCOUNT username password`
	 Response:
	 - `OK` (the account was created)
	 - `ERROR reason`

 - `LOGIN username password`
	Response:
	 - `OK session_token`
	 - `ERROR reason`

 - `LOGOUT session_token`
	Response:
	 - `OK`
	 - `ERROR reason` 

-   `SEND user1,user2,user3 ... message session_token`
    Response:
        -   `OK`
        -   `ERROR reason`

-   `READ_MAILBOX session_token`
    Response:
        -   `OK id1 id2 id3 .. idN`
        -   `ERROR reason`

-   `READ_MSG id`
    Response:
        -   `OK sender:body`
        -   `ERROR reason`


### Client specifications
soon..
