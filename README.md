# Genero mobile app push notification demo

## Description

This demo shows how to implement push notification with Firebase Cloud Messaging (FCM) and with Apple Push Notifications (APNs).

The sources of this demo have been used to write the
 [Genero push notification section of the documentation](http://4js.com/online_documentation/fjs-fgl-manual-html/#fgl-topics/c_fgl_mobile_push_notifications.html)

Push notifications requires a physical device (You can't use a simulator).

The demo uses by default an SQLite database named "tokendb".

The locale settings for server programs must be UTF-8 and FGL_LENGTH_SEMANTICS=CHAR.

If this DB file does not exist, token_maintainer.4gl will create it.

You can switch between FCM and APNs technos with the same token database.

The token_maintainer.4gl program is a Web Service program and should normally be running behing a GAS.
For development/test purpose, it can be run standalone.
The token maintainer must be started first, to collect device registration requests.

![Push notification workflow](https://github.com/FourjsGenero/ex_push_notification/raw/master/docs/push-workflow.png)

## Prerequisites

* Genero BDL 4.01.05+
* Genero Mobile for Android 4.01.06+
* Genero Mobile for iOS 4.01.04+
* Genero Browser Client 4.01.12+
* Genero Desktop Client 4.01.06+
* Genero Studio 4.01.01+
* Java 17+
* GNU Make 4.3+

## Using Firebase Cloud Messaging

### Prepare for FCM

In the FCM console (https://console.firebase.google.com), create a new project,
get the Server Key and the google-services.json configuration file.

For more details, see the topic about FCM in the [Genero documentation](http://4js.com/online_documentation/fjs-fgl-manual-html/#fgl-topics/c_fgl_mobile_push_notif_gcm.html)

### Get the Google Auth JAR files

The fcm_push_server.4gl program uses Java class com.google.auth.oauth2.GoogleCredentials
and therefore you need to get the set of JAR files of the Google Auth API. The simplest
way to get all required JAR files is to use a Maven project.

* If not available on your computer, install Apache Maven
* Go to the directory ext/google_auth
* Check the pom.xml file
* Download the JAR files with following command:
```
$ mvn dependency:copy-dependencies
```


### Build the Android app

Plug your Android device.

Go to the `app` sub-directory.

Copy the google-services.json configuration file in the `app/resources/android` directory.

In main.4gl:
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

Go to the `server` sub-directory.

In fcm_push_server.4gl:
* Define the FCM_SERVER_KEY constant with the FCM Server Key. For testing, you can also
define the FCM_SERVER_KEY environment variable.

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
* Open the fcm.4pw project
* Build all

### Test FCM

1. On the server
   * Start the token_maintainer in background (fglrun token_maintainer &)
   * Start the FCM push server (fglrun fcm_push_server) - has GUI interface!
2. On the Android device:
   * Start the app
   * Tap register button, you should get a registration token
3. On the server:
   * Go to the FCM push server program and click the send button
4. On the Android device:
   * Check that the notification arrives on the device
   * Tap unregister button

## Using Apple Push Notification service

### Prepare for APNS

Read the topics about APNS in the [Genero documentation](http://4js.com/online_documentation/fjs-fgl-manual-html/#fgl-topics/c_fgl_mobile_push_notif_apns.html)

### Build the iOS app

Plug your iOS device.

Go to the `app` sub-directory.

In main.4gl:
* Define the REG_SERVER constant with the hostname where the token_maintainer runs.
* Define the REG_PORT with the port used by token_maintainer.

#### With make

Setup env to build an iOS app with GMI build tool (see build_gmi.sh)

Define the following environment variables:

* GMIDEVICE: The iOS device ID.
* GMICERTIFICATE: The certificate.
* GMIPROVISIONING: The provisioning profile for your app.
* GMIAPPID: The bundle id of your app (like com.fourjs.pushdemo).

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

Go to the `server` sub-directory.

In token_maintainer.4gl:
* Define the DEFAULT_PORT constant with the TCP port number to be used in FGLAPPSERVER.

#### Define security entries in FGLPROFILE

On a Mac, create a APNs certificate for you app, to get the public certificate
and the private key (decrypted) .crt .pem file.
For more details, see
[Genero documentation section about APNS SSL certificates](https://www.4js.com/online_documentation/fjs-fgl-manual-html/#fgl-topics/c_gws_ComAPNS_security.html)

Create your fglprofile file, define FGLPROFILE to point to this file.

```
$ export FGLPROFILE=myprofile
```

Setup the Web Services `security` entries to specify the certificate file and private key file:

```
security.global.certificate = "pusher.crt"
security.global.privatekey  = "pusher_priv.pem"
```

If not executing the server programs on Mac, get the root certificate for Apple
and set the `security.global.ca` entry in fglprofile with that file name:

```
security.global.ca = "apple_entrust_root_certification_authority.pem"
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

1. On the server:
   * Start the token_maintainer in background (fglrun token_maintainer &)
   * Start the APNs push provider (fglrun apns_push_provider) - has GUI interface!
2. On the iOS device:
   * Start the app on iOS
   * Tap register button, you should get a registration token
3. On the server:
   * Go to the APNs push provider program and click the send button
4. On the iOS device:
   * Check that the notification arrives on the device
   * Tap unregister button
