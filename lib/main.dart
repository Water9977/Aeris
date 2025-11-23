import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const NoidaAirApp());
}

class NoidaAirApp extends StatelessWidget {
  const NoidaAirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aeris',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AirQualityScreen(),
    );
  }
}

class AirQualityScreen extends StatefulWidget {
  const AirQualityScreen({super.key});

  @override
  State<AirQualityScreen> createState() => _AirQualityScreenState();
}

class _AirQualityScreenState extends State<AirQualityScreen>
    with SingleTickerProviderStateMixin {
  // AQI State
  double oldAqi = 0;
  double targetAqi = 0;
  String cityName = 'Search a city';
  bool isLoading = false;
  String? errorMessage;
  
  // Refresh Logic State
  String _currentMode = 'gps'; // 'gps', 'city', 'uid'
  String _lastCity = '';
  int _lastUid = 0;

  final TextEditingController _searchController = TextEditingController();
  final String apiToken = '6962881c1ff2da63c27def01268525cb4a159d3c';
  Timer? _debounce;

  // 3D Tilt State
  double xTilt = 0;
  double yTilt = 0;
  late AnimationController _animationController;
  late Animation<double> _tiltAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize Animation Controller for spring-back effect
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _animationController.addListener(() {
      setState(() {
        // Animate back to 0 based on the animation value
      });
    });

    // Try to get current location, fallback to Noida if denied/error
    _initLocationAndFetch();
  }

  // Smart Refresh Handler
  Future<void> _handleRefresh() async {
    if (_currentMode == 'gps') {
      await _initLocationAndFetch();
    } else if (_currentMode == 'city') {
      await fetchAqiByCity(_lastCity);
    } else if (_currentMode == 'uid') {
      await fetchAqiByUid(_lastUid);
    }
  }

  Future<void> _initLocationAndFetch() async {
    setState(() {
      _currentMode = 'gps';
    });
    try {
      final position = await _determinePosition();
      await fetchAqiByLocation(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Location error: $e');
      // Fallback to Noida
      fetchAqiByCity('Noida');
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  // Fetch AQI by Geo-Coordinates
  Future<void> fetchAqiByLocation(double lat, double long) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      _currentMode = 'gps';
    });

    try {
      final url = Uri.parse(
          'https://api.waqi.info/feed/geo:$lat;$long/?token=$apiToken');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'ok') {
          setState(() {
            oldAqi = targetAqi;
            targetAqi = (data['data']['aqi'] is int
                    ? data['data']['aqi']
                    : (data['data']['aqi'] as double))
                .toDouble();
            cityName = data['data']['city']['name'] ?? 'Unknown Location';
            isLoading = false;
          });
        } else {
          _handleError('Unable to fetch AQI data for location.');
        }
      } else {
        _handleError('Failed to fetch data. Please try again.');
      }
    } catch (e) {
      _handleError('Error: ${e.toString()}');
    }
  }

  // Fetch AQI by UID (from autocomplete selection)
  Future<void> fetchAqiByUid(int uid) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      _currentMode = 'uid';
      _lastUid = uid;
    });

    try {
      final url = Uri.parse(
          'https://api.waqi.info/feed/@$uid/?token=$apiToken');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'ok') {
          setState(() {
            oldAqi = targetAqi;
            targetAqi = (data['data']['aqi'] is int
                    ? data['data']['aqi']
                    : (data['data']['aqi'] as double))
                .toDouble();
            cityName = data['data']['city']['name'] ?? 'Unknown';
            isLoading = false;
          });
        } else {
          _handleError('Unable to fetch AQI data.');
        }
      } else {
        _handleError('Failed to fetch data. Please try again.');
      }
    } catch (e) {
      _handleError('Error: ${e.toString()}');
    }
  }

  // Fetch AQI by city name (for Enter key and initial load)
  Future<void> fetchAqiByCity(String city) async {
    if (city.trim().isEmpty) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
      _currentMode = 'city';
      _lastCity = city;
    });

    try {
      final url = Uri.parse(
          'https://api.waqi.info/feed/$city/?token=$apiToken');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'ok') {
          setState(() {
            oldAqi = targetAqi;
            targetAqi = (data['data']['aqi'] is int
                    ? data['data']['aqi']
                    : (data['data']['aqi'] as double))
                .toDouble();
            cityName = data['data']['city']['name'] ?? city;
            isLoading = false;
          });
        } else {
          _handleError('City not found. Please try another city.');
        }
      } else {
        _handleError('Failed to fetch data. Please try again.');
      }
    } catch (e) {
      _handleError('Error: ${e.toString()}');
    }
  }

  void _handleError(String msg) {
    setState(() {
      errorMessage = msg;
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      // Inverted controls for natural feel
      yTilt -= details.delta.dx / 100;
      xTilt += details.delta.dy / 100;

      // Clamp tilt
      xTilt = xTilt.clamp(-0.5, 0.5);
      yTilt = yTilt.clamp(-0.5, 0.5);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final startXTilt = xTilt;
    final startYTilt = yTilt;

    _tiltAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _animationController.reset();
    _animationController.forward();

    _animationController.addListener(() {
      setState(() {
        xTilt = lerpDouble(startXTilt, 0, _tiltAnimation.value) ?? 0;
        yTilt = lerpDouble(startYTilt, 0, _tiltAnimation.value) ?? 0;
      });
    });
  }

  // Search API
  Future<List<Map<String, dynamic>>> searchCities(String keyword) async {
    if (keyword.length < 2) return [];
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    final completer = Completer<List<Map<String, dynamic>>>();

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final url = Uri.parse(
            'https://api.waqi.info/search/?keyword=$keyword&token=$apiToken');
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'ok') {
            final List results = data['data'] ?? [];
            final cities = results.map((item) {
              return {
                'name': item['station']['name'] ?? '',
                'uid': item['uid'] ?? 0,
              };
            }).toList();
            completer.complete(cities);
            return;
          }
        }
      } catch (e) {
        debugPrint('Search error: $e');
      }
      completer.complete([]);
    });

    return completer.future;
  }

  LinearGradient _getGradientForAqi(double aqi) {
    if (aqi <= 50) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00E400), Colors.teal],
      );
    } else if (aqi <= 100) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFD700), Colors.orangeAccent],
      );
    } else if (aqi <= 150) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF7E00), Colors.redAccent],
      );
    } else if (aqi <= 200) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF0000), Color(0xFF800000)],
      );
    } else {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF8F3F97), Colors.black],
      );
    }
  }

  String _getAqiCategory(double aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for Sensitive Groups';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi > 200) return 'Hazardous';
    return 'Unknown';
  }

  // Bouncy Developer Dialog
  void _showDeveloperDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Developer Info',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        child:
                            Icon(Icons.person, size: 40, color: Colors.black),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Siddharth Sharma',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'AI Enthusiast',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const FaIcon(FontAwesomeIcons.linkedin,
                                color: Colors.white),
                            onPressed: () async {
                              const url =
                                  'https://www.linkedin.com/in/siddharth-sharma-310785356?lipi=urn%3Ali%3Apage%3Ad_flagship3_profile_view_base_contact_details%3BbcOYVTn%2FR7uv2P%2F%2BJRyv5w%3D%3D';
                              if (await canLaunchUrl(Uri.parse(url))) {
                                await launchUrl(Uri.parse(url),
                                    mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            icon: const FaIcon(FontAwesomeIcons.envelope,
                                color: Colors.white),
                            onPressed: () async {
                              final Uri emailLaunchUri = Uri(
                                scheme: 'mailto',
                                path: 'sidds9779@gmail.com',
                              );
                              if (await canLaunchUrl(emailLaunchUri)) {
                                await launchUrl(emailLaunchUri,
                                    mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.elasticOut,
          ),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TweenAnimationBuilder<double>(
        key: ValueKey(targetAqi),
        tween: Tween<double>(begin: oldAqi, end: targetAqi),
        duration: const Duration(milliseconds: 2000),
        curve: Curves.easeInOutCubic,
        builder: (context, animatedAqi, child) {
          return Stack(
            children: [
              // Fluid Background
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: _getGradientForAqi(animatedAqi),
                ),
              ),

              // Main Content with Liquid Pull to Refresh
              LiquidPullToRefresh(
                onRefresh: _handleRefresh,
                color: const Color(0xFF1E1E1E),
                backgroundColor: Colors.tealAccent,
                springAnimationDurationInMilliseconds: 500,
                showChildOpacityTransition: false,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    SafeArea(
                      child: Column(
                        children: [
                          // Autocomplete Search Bar
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Autocomplete<Map<String, dynamic>>(
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) async {
                                if (textEditingValue.text.length < 2) {
                                  return const Iterable<Map<String, dynamic>>
                                      .empty();
                                }
                                return await searchCities(
                                    textEditingValue.text);
                              },
                              displayStringForOption:
                                  (Map<String, dynamic> option) =>
                                      option['name'] as String,
                              onSelected: (Map<String, dynamic> selection) {
                                final uid = selection['uid'] as int;
                                fetchAqiByUid(uid);
                                _searchController.clear();
                              },
                              optionsViewBuilder:
                                  (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Material(
                                      color: Colors.transparent,
                                      elevation: 8,
                                      borderRadius: BorderRadius.circular(16),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                              sigmaX: 10, sigmaY: 10),
                                          child: Container(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width -
                                                40,
                                            constraints: const BoxConstraints(
                                                maxHeight: 300),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withOpacity(0.6),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Colors.white
                                                    .withOpacity(0.2),
                                                width: 1,
                                              ),
                                            ),
                                            child: ListView.builder(
                                              padding: const EdgeInsets.all(8),
                                              shrinkWrap: true,
                                              itemCount: options.length,
                                              itemBuilder: (context, index) {
                                                final option =
                                                    options.elementAt(index);
                                                return ListTile(
                                                  title: Text(
                                                    option['name'] as String,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  onTap: () {
                                                    onSelected(option);
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              fieldViewBuilder: (context, controller, focusNode,
                                  onFieldSubmitted) {
                                _searchController.text = controller.text;
                                _searchController.selection =
                                    controller.selection;

                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                          sigmaX: 10, sigmaY: 10),
                                      child: TextField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Search city...',
                                          hintStyle: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.6),
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.search,
                                            color: Colors.white,
                                          ),
                                          suffixIcon: isLoading
                                              ? const Padding(
                                                  padding:
                                                      EdgeInsets.all(12.0),
                                                  child: SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                                  Color>(
                                                              Colors.white),
                                                    ),
                                                  ),
                                                )
                                              : null,
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 16,
                                          ),
                                        ),
                                        onSubmitted: (value) {
                                          if (value.trim().isNotEmpty) {
                                            fetchAqiByCity(value.trim());
                                            controller.clear();
                                            focusNode.unfocus();
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Glass Card Centerpiece
                          Center(
                            child: GestureDetector(
                              onPanUpdate: _onPanUpdate,
                              onPanEnd: _onPanEnd,
                              child: Transform(
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.001) // Perspective
                                  ..rotateX(xTilt)
                                  ..rotateY(yTilt),
                                alignment: Alignment.center,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(32),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      width: MediaQuery.of(context).size.width *
                                          0.85,
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.55,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(32),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (errorMessage != null)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(20.0),
                                              child: Text(
                                                errorMessage!,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  color: Colors.white,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            )
                                          else ...[
                                            Text(
                                              animatedAqi.toInt().toString(),
                                              style: const TextStyle(
                                                fontSize: 120,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                height: 1,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              _getAqiCategory(animatedAqi),
                                              style: const TextStyle(
                                                fontSize: 24,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 8),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 20.0),
                                              child: Text(
                                                cityName,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  color: Colors.white
                                                      .withOpacity(0.8),
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Developer Watermark
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _showDeveloperDialog,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Made with ",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const Icon(Icons.favorite, color: Colors.pink, size: 16),
                      const Text(
                        " by Siddharth Sharma",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
