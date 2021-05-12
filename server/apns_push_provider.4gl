IMPORT com
IMPORT security
IMPORT util

MAIN
    DEFINE rec RECORD
                 msg_title STRING,
                 user_data STRING,
                 info STRING
           END RECORD
    CONNECT TO "tokendb+driver='dbmsqt'"
    OPEN FORM f1 FROM "apns_push_provider"
    DISPLAY FORM f1
    LET rec.msg_title = "Hello, world!"
    LET rec.user_data = "This is a push notification demo"
    INPUT BY NAME rec.* WITHOUT DEFAULTS
             ATTRIBUTES(UNBUFFERED, ACCEPT=FALSE, CANCEL=FALSE)
        ON ACTION send_notification
           LET rec.info = apns_send_message(rec.msg_title, rec.user_data)
        ON ACTION quit
           EXIT INPUT
    END INPUT
END MAIN

FUNCTION apns_send_notif_http(deviceTokenHexa, notif_obj)
    DEFINE deviceTokenHexa STRING,
           notif_obj util.JSONObject
    DEFINE req com.TcpRequest,
           resp com.TcpResponse,
           uuid STRING,
           ecode INTEGER,
           dt DATETIME YEAR TO SECOND,
           exp INTEGER,
           data, err BYTE,
           res STRING

    LOCATE data IN MEMORY
    LOCATE err IN MEMORY

    LET dt = CURRENT + INTERVAL(10) MINUTE TO MINUTE
    LET exp = util.Datetime.toSecondsSinceEpoch(dt)

    TRY  
        --LET req = com.TcpRequest.Create( "tcps://gateway.push.apple.com:2195" )
        LET req = com.TcpRequest.Create( "tcps://gateway.sandbox.push.apple.com:2195" )
        CALL req.setKeepConnection(true)
        CALL req.setTimeOut(2) # Wait 2 seconds for APNs to return error code
        LET uuid = security.RandomGenerator.CreateRandomString(4)
        DISPLAY "PUSH MESSAGE: ", deviceTokenHexa, "/", notif_obj.toString()
        CALL com.APNS.EncodeMessage(
                  data,
                  security.HexBinary.ToBase64(deviceTokenHexa),
                  notif_obj.toString(),
                  uuid,
                  exp,
                  10
             )
        IF length(data) > 2000 THEN
           LET res = "ERROR : APNS payload cannot exceed 2 kilobytes"
           RETURN res
        END IF
        CALL req.doDataRequest(data)
        TRY
            LET resp = req.getResponse()
            CALL resp.getDataResponse(err)        
            CALL com.APNS.DecodeError(err) RETURNING uuid, ecode
            LET res = SFMT("APNS result: UUID: %1, Error code: %2",uuid,ecode)
        CATCH
            CASE status
              WHEN -15553 LET res = "Timeout Push sent without error"
              WHEN -15566 LET res = "Operation failed :", sqlca.sqlerrm
              WHEN -15564 LET res = "Server has shutdown"
              OTHERWISE   LET res = "ERROR :",status
            END CASE
        END TRY
    CATCH
        LET res = SFMT("ERROR : %1 (%2)", status, sqlca.sqlerrm)
    END TRY
    RETURN res
END FUNCTION

FUNCTION apns_simple_popup_notif(notif_obj, msg_title, user_data, badge_number)
    DEFINE notif_obj util.JSONObject,
           msg_title, user_data STRING,
           badge_number INTEGER
    DEFINE aps_obj, data_obj util.JSONObject

    LET aps_obj = util.JSONObject.create()
    CALL aps_obj.put("alert", msg_title)
    CALL aps_obj.put("sound", "default")
    CALL aps_obj.put("badge", badge_number)
    CALL aps_obj.put("content-available", 1)
    CALL notif_obj.put("aps", aps_obj)

    LET data_obj = util.JSONObject.create()
    CALL data_obj.put("other_info", user_data)

    CALL notif_obj.put("custom_data", data_obj)

END FUNCTION

FUNCTION apns_collect_tokens(reg_ids)
    DEFINE reg_ids DYNAMIC ARRAY OF RECORD
                       token STRING,
                       badge INTEGER
                   END RECORD
    DEFINE rec RECORD
               id INTEGER,
               notification_type VARCHAR(10),
               registration_token VARCHAR(250),
               badge_number INTEGER,
               app_user VARCHAR(50),
               reg_date DATETIME YEAR TO FRACTION(3)
           END RECORD,
           x INTEGER
    DECLARE c1 CURSOR FOR
      SELECT * FROM tokens
       WHERE notification_type = "APNS"
    CALL reg_ids.clear()
    FOREACH c1 INTO rec.*
        LET x = reg_ids.getLength() + 1
        LET reg_ids[x].token = rec.registration_token
        LET reg_ids[x].badge = rec.badge_number
    END FOREACH
END FUNCTION

FUNCTION save_badge_number(token, badge)
    DEFINE token STRING,
           badge INT
    UPDATE tokens SET
        badge_number = badge
    WHERE registration_token = token
END FUNCTION

FUNCTION apns_send_message(msg_title, user_data)
    DEFINE msg_title, user_data STRING
    DEFINE reg_ids DYNAMIC ARRAY OF RECORD
                       token STRING,
                       badge INTEGER
                   END RECORD,
           notif_obj util.JSONObject,
           info_msg STRING,
           new_badge, i INTEGER
    CALL apns_collect_tokens(reg_ids)
    IF reg_ids.getLength() == 0 THEN
       RETURN "No registered devices..."
    END IF
    LET info_msg = "Send:"
    FOR i=1 TO reg_ids.getLength()
        LET new_badge = reg_ids[i].badge + 1
        CALL save_badge_number(reg_ids[i].token, new_badge)
        LET notif_obj = util.JSONObject.create()
        CALL apns_simple_popup_notif(notif_obj, msg_title, user_data, new_badge)
        LET info_msg = info_msg, "\n",
            apns_send_notif_http(reg_ids[i].token, notif_obj)
    END FOR
    RETURN info_msg
END FUNCTION
