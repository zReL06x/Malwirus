import 'package:flutter/material.dart';
import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Navigate to home screen after animation completes
        Timer(const Duration(milliseconds: 500), () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        });
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we're in dark mode to choose the appropriate animation
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final animationPath = isDarkMode 
        ? 'assets/animations/splashart_dark.lottie'
        : 'assets/animations/splashart_light.lottie';
    
    return Scaffold(
      // Use transparent background following UI guidelines
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: Center(
        child: DotLottieLoader.fromAsset(
          animationPath,
          frameBuilder: (BuildContext ctx, DotLottie? dotlottie) {
            if (dotlottie != null) {
              return Lottie.memory(
                dotlottie.animations.values.single,
                fit: BoxFit.contain,
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                controller: _controller,
                onLoaded: (composition) {
                  // Start the animation when loaded
                  _controller.duration = composition.duration;
                  _controller.forward();
                },
              );
            } else {
              // Animation is loading
              return const CircularProgressIndicator(
                color: Color(0xFF34C759),
              );
            }
          },
          errorBuilder: (context, error, _) => const Center(
            child: Icon(
              Icons.security,
              size: 80,
              color: Color(0xFF34C759),
            ),
          ),
        ),
      ),
    );
  }
}
