IMPORT com
IMPORT util

IMPORT JAVA com.google.auth.oauth2.GoogleCredentials
IMPORT JAVA java.io.FileInputStream
IMPORT JAVA java.lang.String
IMPORT JAVA java.util.Arrays

CONSTANT FCM_PUSH_BASE_URI = "https://fcm.googleapis.com/v1/projects/%1/messages:%2"
CONSTANT FCM_SCOPE_MESSAGING = "https://www.googleapis.com/auth/firebase.messaging"

CONSTANT FCM_PROJECT_NUM = "..."
CONSTANT FCM_SENDER_ID = "..."
CONSTANT FCM_APP_CRED = "..."

CONSTANT FCM_HTTP_CONTENT_TYPE = "application/json; charset=utf-8"

TYPE t_push_rec RECORD
       project_num STRING,
       access_token STRING,
       msg_title STRING,
       user_data STRING,
       info STRING
     END RECORD

TYPE t_fcm_message RECORD
       message RECORD
         token STRING,
         data RECORD
           title STRING,
           content STRING,
           icon STRING,
           extra_data STRING
         END RECORD
       END RECORD
     END RECORD

MAIN
    DEFINE rec t_push_rec

    CONNECT TO "tokendb+driver='dbmsqt'"

    OPEN FORM f1 FROM "fcm_push_server"
    DISPLAY FORM f1

    LET rec.project_num = get_project_num()
    LET rec.access_token = get_access_token()
    LET rec.msg_title = "Hello world!"
    LET rec.user_data = "This is a push notification demo"
    INPUT BY NAME rec.* WITHOUT DEFAULTS
             ATTRIBUTES(UNBUFFERED, ACCEPT=FALSE, CANCEL=FALSE)
        ON ACTION send_notification
           LET rec.info = fcm_send_notification(rec)
        ON ACTION quit
           EXIT INPUT
    END INPUT

END MAIN

FUNCTION get_project_num() RETURNS STRING
    DEFINE project_num STRING
    LET project_num = fgl_getenv("FCM_PROJECT_NUM")
    IF length(project_num) == 0 THEN
       LET project_num = FCM_PROJECT_NUM
       IF project_num == "..." THEN
          DISPLAY "ERROR: FCM_PROJECT_NUM is not defined."
          EXIT PROGRAM 1
       END IF
    END IF
    RETURN project_num
END FUNCTION

FUNCTION get_access_token() RETURNS STRING
    TYPE string_array_type ARRAY[] OF java.lang.String
    DEFINE credentials_file STRING
    DEFINE google_credentials GoogleCredentials
    DEFINE file_input_stream FileInputStream
    DEFINE scopes string_array_type
    DEFINE access_token STRING
    LET credentials_file = fgl_getenv("FCM_APP_CRED")
    IF length(credentials_file) == 0 THEN
       LET credentials_file = FCM_APP_CRED
       IF credentials_file == "..." THEN
          DISPLAY "ERROR: FCM_APP_CRED is not defined."
          EXIT PROGRAM 1
       END IF
    END IF
    LET scopes = string_array_type.create(1)
    LET scopes[1] = FCM_SCOPE_MESSAGING
    LET file_input_stream = FileInputStream.create(credentials_file)
    LET google_credentials = GoogleCredentials
          .fromStream(file_input_stream)
          .createScoped(Arrays.asList(scopes))
    CALL google_credentials.refresh()
    LET access_token = google_credentials.getAccessToken().getTokenValue()
    RETURN access_token
END FUNCTION

FUNCTION fcm_collect_reg_tokens(reg_ids DYNAMIC ARRAY OF STRING) RETURNS ()
    DEFINE rec RECORD
               id INTEGER,
               notification_type VARCHAR(10),
               registration_token VARCHAR(250),
               badge_number INTEGER,
               app_user VARCHAR(50),
               reg_date DATETIME YEAR TO FRACTION(3)
           END RECORD
    DECLARE c1 CURSOR FOR
      SELECT * FROM tokens
       WHERE notification_type = "FCM"
    CALL reg_ids.clear()
    FOREACH c1 INTO rec.*
        CALL reg_ids.appendElement()
        LET reg_ids[reg_ids.getLength()] = rec.registration_token
    END FOREACH
END FUNCTION

FUNCTION fcm_send_notif_http(
    project_num STRING,
    access_token STRING,
    req_msg STRING -- JSON
) RETURNS STRING
    DEFINE req com.HttpRequest,
           resp com.HttpResponse,
           res STRING
    IF req_msg.getLength() > 4096 THEN
       LET res = "ERROR : FCM message cannot exceed 4 kilobytes"
       RETURN res
    END IF
    LET req = com.HttpRequest.Create(SFMT(FCM_PUSH_BASE_URI,project_num,"send"))
    CALL req.setHeader("Content-Type", FCM_HTTP_CONTENT_TYPE)
    CALL req.setHeader("Authorization", SFMT("Bearer %1", access_token))
    CALL req.setMethod("POST")
    TRY
        CALL req.doTextRequest(req_msg)
        LET resp = req.getResponse()
        CASE resp.getStatusCode()
        WHEN 400 -- Can happen when a device id is invalid (has unregistered)
            LET res = "400 error (maybe some device ids are invalid?)"
        WHEN 200
            LET res = "OK"
        OTHERWISE
            LET res = SFMT("HTTP Error (%1) %2",
                           resp.getStatusCode(),
                           resp.getStatusDescription())
        END CASE
    CATCH
        LET res = SFMT("ERROR : %1 (%2)", status, sqlca.sqlerrm)
    END TRY
    RETURN res
END FUNCTION

FUNCTION fcm_send_notification(rec t_push_rec) RETURNS STRING
    DEFINE reg_ids DYNAMIC ARRAY OF STRING,
           x INTEGER,
           msgrec t_fcm_message,
           res STRING,
           res_list DYNAMIC ARRAY OF STRING
    CALL fcm_collect_reg_tokens(reg_ids)
    IF reg_ids.getLength() == 0 THEN
       RETURN "No registered devices..."
    END IF
    LET msgrec.message.data.title = rec.msg_title
    LET msgrec.message.data.content = rec.user_data
    LET msgrec.message.data.icon = "genero_notification"
    FOR x=1 TO reg_ids.getLength()
        LET msgrec.message.token = reg_ids[x]
        LET res = fcm_send_notif_http( rec.project_num, rec.access_token,
                                       util.JSON.stringify(msgrec) )
        LET res_list[x] = SFMT("Send to token %1 : %2",
                               reg_ids[x].subString(1,10)||"...",res)
    END FOR
    RETURN util.JSON.format(util.JSON.stringify(res_list))
END FUNCTION
