IMPORT com
IMPORT util

CONSTANT FCM_SERVER_KEY = "..." -- Server Key from FCM project

MAIN
    DEFINE rec RECORD
                 server_key STRING,
                 msg_title STRING,
                 user_data STRING,
                 info STRING
           END RECORD
    CONNECT TO "tokendb+driver='dbmsqt'"
    OPEN FORM f1 FROM "fcm_push_server"
    DISPLAY FORM f1
    LET rec.server_key = fgl_getenv("FCM_SERVER_KEY")
    IF length(rec.server_key) == 0 THEN
       LET rec.server_key = FCM_SERVER_KEY
       IF rec.server_key == "..." THEN
          DISPLAY "ERROR: The FCM_SERVER_KEY is not defined."
          EXIT PROGRAM 1
       END IF
    END IF
    LET rec.msg_title = "Hello world!"
    LET rec.user_data = "User data..."
    INPUT BY NAME rec.* WITHOUT DEFAULTS
             ATTRIBUTES(UNBUFFERED, ACCEPT=FALSE, CANCEL=FALSE)
        ON ACTION send_notification
           LET rec.info = fcm_send_text(rec.server_key,
                                        rec.msg_title, rec.user_data)
        ON ACTION quit
           EXIT INPUT
    END INPUT
END MAIN

FUNCTION fcm_send_notif_http(server_key, notif_obj)
    DEFINE server_key STRING,
           notif_obj util.JSONObject
    DEFINE req com.HttpRequest,
           resp com.HttpResponse,
           req_msg, res STRING
    TRY
        LET req = com.HttpRequest.Create("https://fcm.googleapis.com/fcm/send")
        CALL req.setHeader("Content-Type", "application/json")
        CALL req.setHeader("Authorization", SFMT("key=%1", server_key))
        CALL req.setMethod("POST")
        LET req_msg = notif_obj.toString()
        IF req_msg.getLength() > 4096 THEN
           LET res = "ERROR : GCM message cannot exceed 4 kilobytes"
           RETURN res
        END IF
        CALL req.doTextRequest(req_msg)
        LET resp = req.getResponse()
        IF resp.getStatusCode() != 200 THEN
            LET res = SFMT("HTTP Error (%1) %2",
                           resp.getStatusCode(),
                           resp.getStatusDescription())
        ELSE
            LET res = "Push notification sent!"
        END IF
    CATCH
        LET res = SFMT("ERROR : %1 (%2)", status, sqlca.sqlerrm)
    END TRY
    RETURN res
END FUNCTION

FUNCTION fcm_simple_popup_notif(reg_ids, notif_obj, popup_msg, user_data)
    DEFINE reg_ids DYNAMIC ARRAY OF STRING,
           notif_obj util.JSONObject,
           popup_msg, user_data STRING
    DEFINE data_obj, popup_obj util.JSONObject

    CALL notif_obj.put("registration_ids", reg_ids)

    LET data_obj = util.JSONObject.create()

    LET popup_obj = util.JSONObject.create()
    CALL popup_obj.put("title", "Push demo")
    CALL popup_obj.put("content", popup_msg)
    CALL popup_obj.put("icon", "genero")

    CALL data_obj.put("genero_notification", popup_obj)
    CALL data_obj.put("other_info", user_data)

    CALL notif_obj.put("data", data_obj)

END FUNCTION

FUNCTION fcm_collect_tokens(reg_ids)
    DEFINE reg_ids DYNAMIC ARRAY OF STRING
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

FUNCTION fcm_send_text(server_key, msg_title, user_data)
    DEFINE server_key, msg_title, user_data STRING
    DEFINE reg_ids DYNAMIC ARRAY OF STRING,
           notif_obj util.JSONObject,
           info_msg STRING
    CALL fcm_collect_tokens(reg_ids)
    IF reg_ids.getLength() == 0 THEN
       RETURN "No registered devices..."
    END IF
    LET notif_obj = util.JSONObject.create()
    CALL fcm_simple_popup_notif(reg_ids, notif_obj, msg_title, user_data)
    LET info_msg = fcm_send_notif_http(server_key, notif_obj)
    RETURN info_msg
END FUNCTION
