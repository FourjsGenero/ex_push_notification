IMPORT util

DEFINE APNS_APPID STRING
DEFINE APNS_CERTIF STRING

--CONSTANT APNS_DEVICE_URL = "https://api.push.apple.com:443/3/device/%1"
CONSTANT APNS_DEVICE_URL = "https://api.sandbox.push.apple.com:443/3/device/%1"

MAIN
    DEFINE rec RECORD
                 msg_title STRING,
                 user_data STRING,
                 info STRING
           END RECORD
    LET APNS_APPID = fgl_getenv("APNS_APPID")
    IF APNS_APPID IS NULL THEN
        DISPLAY "ERROR: Must define APNS_APPID env var of your APNS app (Bundle ID)"
        EXIT PROGRAM 1
    END IF
    LET APNS_CERTIF = fgl_getenv("APNS_CERTIF")
    IF APNS_CERTIF IS NULL THEN
        DISPLAY "ERROR: Must define APNS_CERTIF env var to .pem certification file"
        EXIT PROGRAM 1
    END IF
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

FUNCTION apns_send_notif_http(deviceTokenHexa, push_type, priority, notif_obj)
    DEFINE deviceTokenHexa STRING,
           push_type STRING,
           priority INTEGER,
           notif_obj util.JSONObject
    DEFINE dt DATETIME YEAR TO SECOND,
           exp INTEGER,
           data STRING,
           cmd STRING,
           s INTEGER

    LET dt = CURRENT + INTERVAL(10) MINUTE TO MINUTE
    LET exp = util.Datetime.toSecondsSinceEpoch(dt)

    IF length(push_type) == 0 THEN
        LET push_type = "alert"
    END IF

    LET data = notif_obj.toString()

    LET cmd = "curl -vs --http2 ",
              SFMT('--header "apns-topic: %1" ',APNS_APPID),
              SFMT('--header "apns-push-type: %1" ',push_type),
              IIF(priority IS NOT NULL, SFMT('--header "apns-priority: %1" ',priority), ""),
              SFMT('--cert "%1" ',APNS_CERTIF), -- *.pem
              SFMT("--data '%1' ",data), -- JSON string!
              SFMT(APNS_DEVICE_URL,deviceTokenHexa)

    DISPLAY "Executing:\n", cmd
    RUN cmd RETURNING s
    IF s != 0 THEN
        RETURN "ERROR : Failed to execute CURL command"
    ELSE
        RETURN cmd
    END IF

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
            apns_send_notif_http(reg_ids[i].token, NULL, NULL, notif_obj)
    END FOR
    RETURN info_msg
END FUNCTION
