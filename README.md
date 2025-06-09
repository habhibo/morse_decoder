Morse Decoder

Overview

Morse Decoder is a mobile application that translates Morse code into text, with a unique feature of decoding Morse code from a flickering flashlight using the device's camera. The app supports both Android and iOS platforms and is built using Unity or Flutter frameworks.

Features





Real-time Morse Code Translation: Decode Morse code signals captured via the device's camera.



Flashlight Integration: Requires access to the device's flashlight for signal input.



Multi-language Support: Currently supports English, with an option to add more languages.



User-friendly Interface: Includes six screens: Menu, Favourites, Translate, Decryptor, Guide, and Add Language.



Screen Orientation: Vertical orientation for optimal user experience.



Guide Pop-up: Accessible via a question mark in the Decryptor screen for user assistance.

Technical Specifications





App Name: Morse Decoder (Store), Decoder (Desktop)



Bundle ID: com.MorseDecoder.MD1605



Operating Systems: Android (minSDK 26, API Level 34), iOS (versions 13-16)



Framework: Unity or Flutter



UI: Enigma Morse Decoder



Screens: 6 (Menu, Favourites, Translate, Decryptor, Guide, Add Language)



Languages: English

Screen Descriptions





Menu: A bottom panel with icons for navigating to other screens.



Favourites: Displays a list of saved translations, clickable to open in the Translate screen.



Translate: Hosts the Morse code translator functionality.



Decryptor: The core feature, using machine vision to decode Morse code from flashlight signals. Includes:





Language selection at the top.



Camera feed display.



Text output field for decoded messages.



Start/End button for signal reception.



Guide pop-up accessible via a question mark in the header.



Guide: Provides instructions on using the app, particularly for decoding signals.



Add Language: Allows users to add support for additional languages.

Installation





Clone the repository:

git clone https://github.com/username/morse-decoder.git



Navigate to the project directory:

cd morse-decoder



Follow the setup instructions for your chosen framework (Unity or Flutter):





Unity: Open the project in Unity Editor, configure for Android/iOS, and build.



Flutter: Run flutter pub get to install dependencies, then build for Android/iOS using flutter run.

Usage





Launch the app on your Android or iOS device.



Grant camera and flashlight permissions when prompted.



Navigate to the Decryptor screen.



Point the camera at a flickering flashlight transmitting Morse code.



Press the Start button to begin decoding.



View the translated text in the output field.



Save translations to Favourites or access the Guide for help.

Contributing

Contributions are welcome! Please follow these steps:





Fork the repository.



Create a new branch (git checkout -b feature/new-feature).



Make your changes and commit (git commit -m "Add new feature").



Push to the branch (git push origin feature/new-feature).



Open a pull request.

License

This project is licensed under the MIT License. See the LICENSE file for details.

Contact

For questions or support, please open an issue on GitHub or contact the maintainers.
