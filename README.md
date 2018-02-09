# Genero mobile app push notification demo

## Description

This demo shows how to implement push notification with Google Cloud Messaging (GCM) and with Apple Push Notifications (APNs).

The demo uses by default an SQLite database named "tokendb".

If this DB file does not exist, token_maintainer.4gl will create it.

You can switch between GCM and APNs technos with the same token database:

The programs check for the sender_id, which is specific to GCM.

The token_maintainer.4gl program is a Web Service program and should normally be running behing a GAS. For development/test purpose, it can be run standalone.

The token maintainer must be started first, to collect device registration requests.

You need a physical device (You can't use a simulator)

![Push notification workflow](https://github.com/FourjsGenero/ex_push_notification/raw/master/docs/push-workflow.png)

## Using Google Could Messaging

Create a GCM project at Google to get API Key and Sender ID.

In main.4gl:
* Define the GCM_SENDER_ID constant with the GCM Sender ID.
* Define the REG_SERVER constant with the hostname when token_maintainer runs.
* Define the REG_PORT with the port used by token_maintainer.

In gcm_push_server.4gl:
* define the GCM_API_KEY constant with the GCM API KEY.

```
make clean all
```

Build/deploy the Android app:
* Setup env to build an Android app with GMA build tool (see gma_build.sh)
* plug your device
* make gma_app

Start the token_maintainer (fglrun token_maintainer)

Start the GCM push server (fglrun gcm_push_server) - has GUI interface!

Start the app on Android:
* tap register button, you should get a registration token

Go to the GCM push server program and click the send button

Check that the notification arrives on the device.

In the app, tap unregister button.

## Using Apple Push Notification service

If not executing the server programs on Mac, get the root certificate for Apple and set security.global.ca in fglprofile with that file name (apple_entrust_root_certification_authority.pem)

On a Mac, create a APNs certificate for you app, to get the public certificate and the private key (decrypted) .crt .pem
For more details about creating, see BDL documentation, in the index search for APNS SSL certificate or go directly to this link:
https://www.4js.com/online_documentation/fjs-fgl-manual-html/#c_gws_ComAPNS_security.html

Setup fglprofile entries to specify the certificate file and private key file:
```
security.global.certificate = "pusher.crt"
security.global.privatekey  = "pusher_priv.pem"
```

In main.4gl:
* Define the GCM_SENDER_ID constant as ""
* Define the REG_SERVER constant with the hostname when token_maintainer runs.
* Define the REG_PORT with the port used by token_maintainer.

```
make clean all
```

Build the iOS app:
* Setup env to build an iOS app with GMI build tool (see gmi_build.sh)
* plug your device
* make gmi_app

Edit the fglprofile file to define the security entries to access Apple servers.

Set FGLPROFILE=fglprofile (for certification / private key)

Start the token_maintainer with APNS argument (fglrun token_maintainer APNS)

Start the APNs push provider (fglrun apns_push_provider) - has GUI interface!

Start the app on iOS:
* tap register button, you should get a registration token

Go to the APNs push provider program and click the send button.

Check that the notification arrives on the device.

In the app, tap unregister button.
