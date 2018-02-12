# Genero mobile app push notification demo

## Description

This demo shows how to implement push notification with Google Cloud Messaging (GCM) and with Apple Push Notifications (APNs).

The sources of this demo have been used to write the
 [Genero push notification section of the documentation](http://4js.com/online_documentation/fjs-fgl-manual-html/#fgl-topics/c_fgl_mobile_push_notifications.html)

Push notifications requires a physical device (You can't use a simulator).

The demo uses by default an SQLite database named "tokendb".

If this DB file does not exist, token_maintainer.4gl will create it.

You can switch between GCM and APNs technos with the same token database:
The programs check for the sender_id, which is specific to GCM.

The token_maintainer.4gl program is a Web Service program and should normally be running behing a GAS. For development/test purpose, it can be run standalone.

The token maintainer must be started first, to collect device registration requests.

![Push notification workflow](https://github.com/FourjsGenero/ex_push_notification/raw/master/docs/push-workflow.png)

## Prerequisites

* Genero BDL 3.10.11+
* Genero Desktop Client 3.10+
* Genero Studio 3.10+
* GNU Make

## Using Google Could Messaging

### Prepare for GCM

Create a GCM project at Google to get API Key and Sender ID.

Read the topic about GCM in the [Genero documentation](http://4js.com/online_documentation/fjs-fgl-manual-html/#fgl-topics/c_fgl_mobile_push_notif_gcm.html)

### Build the Android app

Plug your Android device.

Go to the app sub-directory.

In main.4gl:
* Define the GCM_SENDER_ID constant with the GCM Sender ID.
* Define the REG_SERVER constant with the hostname where the token_maintainer runs.
* Define the REG_PORT with the port used by token_maintainer.

#### With make

Setup env to build an Android app with GMA build tool (see build_gma.sh)

```
$ make clean all
$ make appdir
$ make package_gma
```

#### With GST

* Open the pushdemo.4pw project
* Setup GST Android SDK environment
* Enable the pushdemo_android packaging rules
* Build all
* Install the APK created in the build/packages directory

### Build the server programs

Go to the server sub-directory.

In gcm_push_server.4gl:
* Define the GCM_API_KEY constant with the GCM API KEY.

In token_maintainer.4gl:
* Define the DEFAULT_PORT constant with the TCP port number to be used in FGLAPPSERVER.

#### With make

```
$ make clean all
```

#### With GST

* Setup GST Desktop environment
* Open the token_maintainer.4pw project
* Build all
* Open the gcm.4pw project
* Build all

### Test GCM

* On the server: Start the token_maintainer (fglrun token_maintainer)
* On the server: Start the GCM push server (fglrun gcm_push_server) - has GUI interface!
* On the Android device: Start the app
* On the Android device: Tap register button, you should get a registration token
* On the server: Go to the GCM push server program and click the send button
* On the Android device: Check that the notification arrives on the device
* On the Android device the app, tap unregister button

## Using Apple Push Notification service

### Prepare for APNS

Read the topics about APNS in the [Genero documentation](http://4js.com/online_documentation/fjs-fgl-manual-html/#fgl-topics/c_fgl_mobile_push_notif_apns.html)

### Build the iOS app

Plug your iOS device.

Go to the app sub-directory.

In main.4gl:
* Define the GCM_SENDER_ID constant as ""
* Define the REG_SERVER constant with the hostname where the token_maintainer runs.
* Define the REG_PORT with the port used by token_maintainer.

#### With make

Setup env to build an iOS app with GMI build tool (see build_gmi.sh)

```
$ make clean all
$ make appdir
$ make package_gmi
```

#### With GST

* Open the pushdemo.4pw project
* Setup GST iOS developer environment
* Enable the pushdemo_ios packaging rules
* Build all
* Install the IPA created in the build/packages directory


### Build the server programs

Go to the server sub-directory.

In token_maintainer.4gl:
* Define the DEFAULT_PORT constant with the TCP port number to be used in FGLAPPSERVER.

#### Define security entries in FGLPROFILE

Create your fglprofile file, define FGLPROFILE to point to this file.

```
$ export FGLPROFILE=myprofile 
```

Edit the fglprofile file to define the security entries to access Apple servers.

If not executing the server programs on Mac, get the root certificate for Apple and set security.global.ca in fglprofile with that file name (apple_entrust_root_certification_authority.pem)

```
security.global.ca = "apple_entrust_root_certification_authority.pem"
```

On a Mac, create a APNs certificate for you app, to get the public certificate and the private key (decrypted) .crt .pem
For more details, see [Genero documentation section about APNS SSL certificates](https://www.4js.com/online_documentation/fjs-fgl-manual-html/#fgl-topics/c_gws_ComAPNS_security.html)

Setup the fglprofile entries to specify the certificate file and private key file:

```
security.global.certificate = "pusher.crt"
security.global.privatekey  = "pusher_priv.pem"
```

#### With make

```
$ make clean all
```

#### With GST

* Setup GST Desktop environment
* Open the token_maintainer.4pw project
* Build all
* Open the apns.4pw project
* Build all

### Test APNS

* On the server: Start the token_maintainer with APNS argument (fglrun token_maintainer APNS)
* On the server: Start the APNs push provider (fglrun apns_push_provider) - has GUI interface!
* On the iOS device: Start the app on iOS
* On the iOS device: Tap register button, you should get a registration token
* On the server: Go to the APNs push provider program and click the send button
* On the iOS device: Check that the notification arrives on the device
* on the iOS device: Tap unregister button
