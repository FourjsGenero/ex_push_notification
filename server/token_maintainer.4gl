IMPORT util
IMPORT com
IMPORT os

CONSTANT DEFAULT_PORT = 9999

MAIN
    CALL open_create_db()
    CALL handle_registrations()
END MAIN

FUNCTION open_create_db() RETURNS ()
    DEFINE dbsrc VARCHAR(100),
           x INTEGER
    IF NOT os.Path.exists("tokendb") THEN
       CALL create_empty_file("tokendb")
    END IF
    LET dbsrc = "tokendb+driver='dbmsqt'"
    CONNECT TO dbsrc
    WHENEVER ERROR CONTINUE
    SELECT COUNT(*) INTO x FROM tokens
    WHENEVER ERROR STOP
    IF sqlca.sqlcode<0 THEN
       CREATE TABLE tokens (
              id INTEGER NOT NULL PRIMARY KEY,
              notification_type VARCHAR(10) NOT NULL,
              registration_token VARCHAR(250) NOT NULL UNIQUE,
              badge_number INTEGER NOT NULL,
              app_user VARCHAR(50) NOT NULL, -- UNIQUE
              reg_date DATETIME YEAR TO FRACTION(3) NOT NULL
       )
    END IF
END FUNCTION

FUNCTION create_empty_file(fn STRING) RETURNS ()
    DEFINE c base.Channel
    LET c = base.Channel.create()
    CALL c.openFile(fn, "w")
    CALL c.close()
END FUNCTION

FUNCTION handle_registrations() RETURNS ()
    DEFINE req com.HttpServiceRequest,
           url, method, version, content_type STRING,
           reg_data, reg_result STRING
    IF length(fgl_getenv("FGLAPPSERVER"))==0 THEN
       -- Normally, FGLAPPSERVER is set by the GAS
       DISPLAY SFMT("Setting FGLAPPSERVER to %1", DEFAULT_PORT)
       CALL fgl_setenv("FGLAPPSERVER", DEFAULT_PORT)
    END IF
    CALL com.WebServiceEngine.Start()
    WHILE TRUE
       TRY
          LET req = com.WebServiceEngine.GetHTTPServiceRequest(20)
       CATCH
          IF status==-15565 THEN
             DISPLAY "TCP socket probably closed by GAS, stopping process..."
             EXIT PROGRAM 0
          ELSE
             DISPLAY "Unexpected getHttpServiceRequest() exception: ", status
             DISPLAY "Reason: ", sqlca.sqlerrm
             EXIT PROGRAM 1
          END IF
       END TRY
       IF req IS NULL THEN -- timeout
          DISPLAY SFMT("HTTP request timeout...: %1", CURRENT YEAR TO FRACTION)
          CALL show_tokens()
          CONTINUE WHILE
       END IF
       LET url = req.getUrl()
       LET method = req.getMethod()
       IF method IS NULL OR method != "POST" THEN
          IF method == "GET" THEN
             CALL req.sendTextResponse(200,NULL,"Hello from token maintainer...")
          ELSE
             DISPLAY SFMT("Unexpected HTTP request: %1", method)
             CALL req.sendTextResponse(400,NULL,"Only POST requests supported")
          END IF
          CONTINUE WHILE
       END IF
       LET version = req.getRequestVersion()
       IF version IS NULL OR version != "1.1" THEN
          DISPLAY SFMT("Unexpected HTTP request version: %1", version)
          CONTINUE WHILE
       END IF
       LET content_type = req.getRequestHeader("Content-Type")
       IF content_type IS NULL
          OR content_type NOT MATCHES "application/json*" -- ;Charset=UTF-8
       THEN
          DISPLAY SFMT("Unexpected HTTP request header Content-Type: %1", content_type)
          CALL req.sendTextResponse(400,NULL,"Bad request")
          CONTINUE WHILE
       END IF
       TRY
          CALL req.readTextRequest() RETURNING reg_data
       CATCH
          DISPLAY SFMT("Unexpected HTTP request read exception: %1", status)
       END TRY
       LET reg_result = process_command(url, reg_data)
       CALL req.setResponseCharset("UTF-8")
       CALL req.setResponseHeader("Content-Type","application/json")
       CALL req.sendTextResponse(200,NULL,reg_result)
    END WHILE
END FUNCTION

FUNCTION process_command(url STRING, data STRING) RETURNS STRING
    DEFINE data_rec RECORD
               notification_type VARCHAR(10),
               registration_token VARCHAR(250),
               badge_number INTEGER,
               app_user VARCHAR(50)
           END RECORD,
           p_id INTEGER,
           p_ts DATETIME YEAR TO FRACTION(3),
           result_rec RECORD
               status INTEGER,
               message STRING
           END RECORD,
           result STRING
    LET result_rec.status = 0
    TRY
       CASE
         WHEN url MATCHES "*token_maintainer/register"
           CALL util.JSON.parse( data, data_rec )
           SELECT id INTO p_id FROM tokens
                  WHERE registration_token = data_rec.registration_token
           IF p_id > 0 THEN
              LET result_rec.status = 1
              LET result_rec.message = SFMT("Token already registered:\n [%1]",
                                            data_rec.registration_token)
              GOTO pc_end
           END IF
           SELECT MAX(id) + 1 INTO p_id FROM tokens
           IF p_id IS NULL THEN LET p_id=1 END IF
           LET p_ts = util.Datetime.toUTC(CURRENT YEAR TO FRACTION(3))
           WHENEVER ERROR CONTINUE
           INSERT INTO tokens
               VALUES( p_id, data_rec.notification_type,
                       data_rec.registration_token, 0, data_rec.app_user, p_ts )
           WHENEVER ERROR STOP
           IF sqlca.sqlcode==0 THEN
              LET result_rec.message = SFMT("Token is now registered:\n [%1]",
                                            data_rec.registration_token)
           ELSE
              LET result_rec.status = -2
              LET result_rec.message = SFMT("Could not insert token in database:\n [%1]",
                                            data_rec.registration_token)
           END IF
         WHEN url MATCHES "*token_maintainer/unregister"
           CALL util.JSON.parse( data, data_rec )
           DELETE FROM tokens
                  WHERE registration_token = data_rec.registration_token
           IF sqlca.sqlerrd[3]==1 THEN
              LET result_rec.message = SFMT("Token unregistered:\n [%1]",
                                            data_rec.registration_token)
           ELSE
              LET result_rec.status = -3
              LET result_rec.message = SFMT("Could not find token in database:\n [%1]",
                                            data_rec.registration_token)
           END IF
         WHEN url MATCHES "*token_maintainer/badge_number"
            CALL util.JSON.parse( data, data_rec )
            WHENEVER ERROR CONTINUE
              UPDATE tokens
                 SET badge_number = data_rec.badge_number 
               WHERE registration_token = data_rec.registration_token
            WHENEVER ERROR STOP
            IF sqlca.sqlcode==0 THEN
               LET result_rec.message =
                   SFMT("Badge number updated for Token:\n [%1]\n New value:[%2]\n",
                        data_rec.registration_token, data_rec.badge_number)
            ELSE
               LET result_rec.status = -4
               LET result_rec.message = SFMT("Badge update failed for token:\n [%1]",
                                             data_rec.registration_token)
            END IF
       END CASE
    CATCH
       LET result_rec.status = -1
       LET result_rec.message = SFMT("Failed to register token:\n [%1]",
                                     data_rec.registration_token)
    END TRY
LABEL pc_end:
    DISPLAY result_rec.message
    LET result = util.JSON.stringify(result_rec)
    RETURN result
END FUNCTION

FUNCTION show_tokens() RETURNS ()
    DEFINE rec RECORD -- Use CHAR to format
               id INTEGER,
               notification_type CHAR(10),
               registration_token CHAR(250),
               badge_number INTEGER,
               app_user CHAR(50),
               reg_date DATETIME YEAR TO FRACTION(3)
           END RECORD
    DECLARE c1 CURSOR FOR SELECT * FROM tokens ORDER BY id
    FOREACH c1 INTO rec.*
        DISPLAY "   ", rec.id, ": ",
                       rec.notification_type,": ",
                       rec.app_user[1,10], " / ",
                       "(",rec.badge_number USING "<<<<&", ") ",
                       rec.registration_token[1,20],"..."
    END FOREACH
    IF rec.id == 0 THEN
       DISPLAY "No tokens registered yet..."
    END IF
END FUNCTION
