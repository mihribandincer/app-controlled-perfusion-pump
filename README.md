# app-controlled-perfusion-pump
Smart infusion pump system developed using Arduino and Flutter. Enables mobile-controlled drug delivery with real-time feedback via Bluetooth (HC-05).
Abstract
This project presents the design and implementation of a smart, syringe-based perfusion pump system integrated with a Flutter-based mobile application. The device is developed using an Arduino Mega microcontroller, stepper motor, A4988 driver, 4x4 keypad, I2C LCD display, fluid level sensor (XKC-Y26-V), and HC-05 Bluetooth module. The system allows healthcare professionals to define the volume (mL) and duration (min) of drug infusion via a user-friendly mobile interface.

Once initiated, the pump delivers the specified amount of fluid within the given time frame. Upon completion, the system detects whether the syringe is empty or still contains fluid using sensor feedback, and sends an appropriate notification message ("PERFUSION COMPLETED - FLUID EMPTY / FLUID PRESENT") to the mobile device. This enables remote monitoring and enhances patient safety by providing real-time status updates.

The application was developed in Flutter for its cross-platform capabilities and streamlined UI design. The integration of hardware and software components demonstrates a low-cost, customizable, and portable solution for controlled drug delivery in clinical or home-care settings.

for contact: mihribandncr12@gmail.com
