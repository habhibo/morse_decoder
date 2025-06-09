
# Morse Decoder App
Morse Decoder is a mobile application designed to translate Morse code, including the ability to decode Morse code from a flickering flashlight using your device's camera.

# Technical Characteristics
App Name:
Store Name: Morse Decoder 
Desktop Name: Decoder 
Bundle ID: com.MorseDecoder.MD1605 
UI: Figma Morse Decoder 
Operating System (OS): Android, iOS 
Framework: Unity/Flutter 
minSDK version: 26 
API Level: 34 
iOS Version Compatibility: No higher than 13-16 
Screen Orientation: Vertical 
Number of Screens: 6 
Languages: English 
Required Permissions: Access to the flashlight 
App Description and Unique Selling Proposition (USP)
This application serves as a Morse code translator with a unique capability: it can read Morse code from the flicker of a flashlight using the device's camera.

# Screen Scheme
The app consists of the following screens:

# Menu 
Favourites 
Translate 
Decryptor 
Guide 
Add language 
Screens and Buttons

# 1. Menu
The Menu is not a separate screen but a panel at the bottom of the screen containing icons for switching to different screens. It includes buttons for:

Translate 
Decryptor 
Favourite 

# 2. Translate
This screen hosts the translator functionality.

# 3. Add Language
On this screen, users can add a new language, edit an existing one, or add new characters. Clicking on an existing language allows for editing. Each symbol has a function to play it with a vibrator or flashlight.


# 4. Favourites
This screen displays all saved translations in a list. Tapping on a saved text opens it in the translation screen.


# 5. Decryptor
This is the main feature of the application, incorporating a decoder that uses machine vision.


At the top of the screen, the user selects the language for translation.



The user sees what their camera sees, and they need to point the camera at the source of information to perform a decryption.


The received text is displayed in a field below.


A start/end button for receiving information is located in the lower part of the screen.


When the camera is pointed at a flickering flashlight and information reception is activated, the app recognizes the transmitted symbol and converts it into text, displaying the result in the lower field.

A question mark icon in the upper-right corner of the screen header opens the Guide pop-up window.

# 6. Guide
This screen provides information on how to use the decryption function. Users can receive a signal from a distance and decipher it by pointing the camera at the light source. The app will then translate the received information into the chosen language. To send a message, users can play the cipher with the device's flashlight on the translation screen.

