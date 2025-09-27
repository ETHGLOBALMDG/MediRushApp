import 'package:flutter/material.dart';

const lightColor = Color.fromARGB(255, 217, 217, 217);
const lightGreenColor = Color.fromARGB(255, 228, 246, 239);
const greenColor = Color.fromARGB(255, 76, 175, 80);

const headingTextStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  fontFamily: "Poppins",
);

const heading2TextStyle = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.bold,
  fontFamily: "Poppins",
);

const subheadingTextStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: Colors.grey,
  fontFamily: "Poppins",
);

const bodyTextStyle = TextStyle(
  fontSize: 13,
  color: Colors.black38,
  fontWeight: FontWeight.w400,
  fontFamily: "Poppins",
);

const body2TextStyle = TextStyle(
  fontSize: 15,
  color: Colors.black38,
  fontWeight: FontWeight.w400,
  fontFamily: "Poppins",
);

const body2DarkTextStyle = TextStyle(
  fontSize: 16,
  color: Colors.black,
  fontWeight: FontWeight.w400,
  fontFamily: "Poppins",
);

const buttonTextStyle = TextStyle(
  fontSize: 15,
  color: Colors.black,
  fontWeight: FontWeight.w500,
  fontFamily: "Poppins",
);

Widget rowButton({
  required VoidCallback onPressed,
  required List<Widget> widgets,
  Color backgroundColor = Colors.grey, // default background
  Color foregroundColor = Colors.black, // default text/icon color
  double borderRadius = 8.0, // default rounded corners
  EdgeInsetsGeometry? padding, // optional custom padding
}) {
  return TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: widgets,
    ),
  );
}
