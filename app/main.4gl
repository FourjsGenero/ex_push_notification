IMPORT com
IMPORT util
IMPORT os

CONSTANT REG_SERVER = "toro"  -- Change to your hostname
CONSTANT REG_PORT = 9999

DEFINE rec RECORD
           tm_host STRING,
           tm_port INTEGER,
           notification_type STRING,
           user_name STRING,
           registration_token STRING,
           notifications STRING
       END RECORD

MAIN

    CALL load_settings()

    OPEN FORM f1 FROM "pushclient"
    DISPLAY FORM f1

    IF ui.Interface.getFrontEndName()=="GMA" THEN
        LET rec.notification_type = "FCM"
    ELSE
        LET rec.notification_type = "APNS"
    END IF

    INPUT BY NAME rec.*
         ATTRIBUTES(WITHOUT DEFAULTS, UNBUFFERED, CANCEL=FALSE, ACCEPT=FALSE)
      ON ACTION register
         LET rec.registration_token = register(rec.notification_type, rec.user_name)
         CALL save_settings()
      ON ACTION unregister
         CALL unregister(rec.notification_type, rec.registration_token, rec.user_name)
         LET rec.registration_token = NULL
         CALL save_settings()
      ON ACTION notificationpushed
         CALL handle_notification()
      ON ACTION quit ATTRIBUTES(TEXT="Quit")
         CALL save_settings()
         EXIT INPUT
    END INPUT

END MAIN

FUNCTION get_settings_file()
    RETURN os.Path.join(os.Path.pwd(),"pushclient.dat")
END FUNCTION

FUNCTION load_settings()
    DEFINE fn, data STRING,
           ch base.Channel
    LET fn = get_settings_file()
    LET ch = base.Channel.create()
    TRY
        CALL ch.openFile(fn,"r")
        LET data = ch.readLine()
        CALL util.JSON.parse( data, rec )
        CALL ch.close()
    CATCH
        LET rec.tm_host = NULL
    END TRY
    IF rec.tm_host IS NULL THEN
       LET rec.tm_host = REG_SERVER
       LET rec.tm_port = REG_PORT
       LET rec.user_name = "mike"
    END IF
END FUNCTION

FUNCTION save_settings()
    DEFINE fn, data STRING,
           ch base.Channel
    LET data = util.JSON.stringify( rec )
    LET fn = get_settings_file()
    LET ch = base.Channel.create()
    CALL ch.openFile(fn,"w")
    CALL ch.writeLine(data)
    CALL ch.close()
END FUNCTION

FUNCTION register(notification_type, app_user)
    DEFINE notification_type STRING,
           app_user STRING
    DEFINE registration_token STRING
    TRY
        CALL ui.Interface.frontCall(
                "mobile", "registerForRemoteNotifications", 
                [ ], [ registration_token ] )
        IF tm_command( "register", notification_type,
                       registration_token, app_user, 0 ) < 0 THEN
           RETURN NULL
        END IF
    CATCH
        MESSAGE "Registration failed!."
        RETURN NULL
    END TRY
    MESSAGE "Registration succeeded!"
    RETURN registration_token
END FUNCTION

FUNCTION unregister(notification_type, registration_token, app_user)
    DEFINE notification_type STRING,
           registration_token STRING,
           app_user STRING
    IF tm_command( "unregister", notification_type,
                   registration_token, app_user, 0 ) < 0 THEN
       RETURN
    END IF
    TRY
        CALL ui.Interface.frontCall(
                "mobile", "unregisterFromRemoteNotifications", 
                [ ], [ ] )
    CATCH
        MESSAGE "Un-registration failed (broacast service)."
        RETURN
    END TRY
    MESSAGE "Un-registration succeeded"
END FUNCTION

FUNCTION tm_command( command, notification_type, registration_token,
                     app_user, badge_number )
    DEFINE command STRING,
           notification_type STRING,
           registration_token STRING,
           app_user STRING,
           badge_number INTEGER
    DEFINE url STRING,
           json_obj util.JSONObject,
           req com.HttpRequest,
           resp com.HttpResponse,
           json_result STRING,
           result_rec RECORD
                          status INTEGER,
                          message STRING
                      END RECORD
    TRY
        LET url = SFMT( "http://%1:%2/token_maintainer/%3",
                        rec.tm_host, rec.tm_port, command )
        LET req = com.HttpRequest.Create(url)
        CALL req.setHeader("Content-Type", "application/json")
        CALL req.setMethod("POST")
        CALL req.setConnectionTimeOut(5)
        CALL req.setTimeOut(5)
        LET json_obj = util.JSONObject.create()
        CALL json_obj.put("notification_type", notification_type)
        CALL json_obj.put("registration_token", registration_token)
        CALL json_obj.put("app_user", app_user)
        CALL json_obj.put("badge_number", badge_number)
        CALL req.doTextRequest(json_obj.toString())
        LET resp = req.getResponse()
        IF resp.getStatusCode() != 200 THEN
           MESSAGE SFMT("HTTP Error (%1) %2",
                      resp.getStatusCode(),
                      resp.getStatusDescription())
           RETURN -2
        ELSE
           LET json_result = resp.getTextResponse()
           CALL util.JSON.parse(json_result, result_rec)
           IF result_rec.status >= 0 THEN
              RETURN 0
           ELSE
              MESSAGE SFMT("Notification maintainer message:\n %1", result_rec.message)
              RETURN -3
           END IF
        END IF
    CATCH
        MESSAGE SFMT("Failed to post token registration command: %1", status)
        RETURN -1
    END TRY
END FUNCTION

FUNCTION setup_badge_number(consumed)
    DEFINE consumed INTEGER
    DEFINE badge_number INTEGER
    TRY -- If the front call fails, we are not on iOS...
        CALL ui.Interface.frontCall("ios", "getBadgeNumber", [], [badge_number])
    CATCH
        RETURN
    END TRY
    IF badge_number>0 THEN
       LET badge_number = badge_number - consumed
    END IF
    CALL ui.Interface.frontCall("ios", "setBadgeNumber", [badge_number], [])
    IF tm_command( "badge_number", "APNS", rec.registration_token,
                   rec.user_name, badge_number) < 0 THEN
       ERROR "Could not send new badge number to token maintainer."
       RETURN
    END IF
END FUNCTION

FUNCTION handle_notification()
    DEFINE notif_list STRING,
           notif_array util.JSONArray,
           notif_item util.JSONObject,
           notif_data util.JSONObject,
           aps_record util.JSONObject,
           fcm_data_s STRING,
           fcm_genero_notification_s STRING,
           fcm_genero_notification util.JSONObject,
           info, other_info STRING,
           i, x INTEGER
    CALL ui.Interface.frontCall(
              "mobile", "getRemoteNotifications",
              [ ], [ notif_list ] )
    TRY
        IF notif_list.trimLeft() NOT LIKE "[%" THEN -- GBC-3043 Workaround
           LET notif_list = "[ ", notif_list, " ]"
        END IF
        LET notif_array = util.JSONArray.parse(notif_list)
        IF notif_array.getLength() > 0 THEN
           CALL setup_badge_number(notif_array.getLength())
        END IF
        FOR i=1 TO notif_array.getLength()
            LET info = NULL
            LET other_info = NULL
            LET notif_item = notif_array.get(i)
            -- Try APNs msg format
            LET aps_record = notif_item.get("aps")
            IF aps_record IS NOT NULL THEN
               LET info = aps_record.get("alert")
               LET notif_data = notif_item.get("custom_data")
               IF notif_data IS NOT NULL THEN
                  LET other_info = notif_data.get("other_info")
               END IF
            ELSE
               -- Try FCM msg format
               LET fcm_data_s = notif_item.get("data")
               IF fcm_data_s IS NOT NULL THEN
                  LET notif_data = util.JSONObject.parse(fcm_data_s)
                  IF notif_data IS NOT NULL THEN
                     LET fcm_genero_notification_s = notif_data.get("genero_notification")
                     LET fcm_genero_notification = util.JSONObject.parse(
                                                        fcm_genero_notification_s )
                     IF fcm_genero_notification IS NOT NULL THEN
                        LET info = fcm_genero_notification.get("content")
                     END IF
                     LET other_info = notif_data.get("other_info")
                  END IF
               END IF
            END IF
            IF info IS NULL THEN
               LET info = "Unexpected message format"
            END IF
            LET x = x + 1
            LET rec.notifications = rec.notifications, "\n",
                    SFMT("%1(%2): %3[%4]", x, CURRENT HOUR TO SECOND, info, other_info)
        END FOR
    CATCH
        MESSAGE "Could not extract notification info"
    END TRY
END FUNCTION
