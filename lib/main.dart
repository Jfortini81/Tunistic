import 'dart:convert';

import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:tunistic_app/hearted_songs_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Final
Future main() async {
  await dotenv.load();
  runApp(const MyApp());
}

class HeartedTrackTile extends StatefulWidget {
  final Map<String, dynamic> track;

  HeartedTrackTile({required this.track});

  @override
  _HeartedTrackTileState createState() => _HeartedTrackTileState();
}

class _HeartedTrackTileState extends State<HeartedTrackTile> {
  bool isHearted = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    isHearted = HeartedSongsProvider.of(context).isHearted(widget.track);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        child: ListTile(
      leading: Image.network(widget.track['album']['images'][0]['url']),
      title: Text(
        widget.track['name'],
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        widget.track['artists'][0]['name'],
        style: const TextStyle(color: Colors.white),
      ),
      trailing: IconButton(
        icon: Icon(
          isHearted ? Icons.favorite : Icons.favorite_border,
          color: const Color((0xFFD14853)),
        ),
        onPressed: () {
          setState(() {
            isHearted = !isHearted;
          });
          final heartedSongs = HeartedSongsProvider.of(context);
          heartedSongs.toggle(widget.track['id'], widget.track);
          if (isHearted) {
            heartedSongs.isHearted(widget.track);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Added to favorites'),
                duration: Duration(seconds: 1),
              ),
            );
          } else {
            heartedSongs.isHearted(widget.track);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Removed from favorites'),
                duration: Duration(seconds: 1),
              ),
            );
          }
        },
      ),
    ));
  }
}

// The actual Favorites Screen
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final heartedTracks = HeartedSongsProvider.of(context).heartedTracks;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: heartedTracks.isEmpty
          ? const Center(
              child: Text(
                'No Favorites Tracks Yet',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
            )
          : ListView.builder(
              itemCount: heartedTracks.length,
              itemBuilder: (context, index) {
                final track = heartedTracks[index];
                return HeartedTrackTile(track: track);
              },
            ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  //Getting my hexadecimal color
  MaterialColor buildMaterialColor(Color color) {
    List strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }

  @override
  Widget build(BuildContext context) {
    return HeartedSongsProvider(
      child: MaterialApp(
        title: 'Tunistic',
        theme: ThemeData(
          scaffoldBackgroundColor: const Color(0xFF0C181D),
          fontFamily: GoogleFonts.righteous().fontFamily,
          primarySwatch: buildMaterialColor(const Color(0xFFD14853)),
        ),
        home: SearchScreen(),
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  String? _trackId;
  List<dynamic>? _recommendations;
  int currentIndex = 0;
  AudioPlayer player = AudioPlayer();
  int? playingIndex;
  bool isPlaying = false;

  void onTabTapped(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  // Searches for a track
  Future<void> _searchTrack() async {
    final clientId = dotenv.env['CLIENT_ID'] ?? 'Client ID Not Found';
    final clientSecret =
        dotenv.env['CLIENT_SECRET'] ?? 'Client Secret Not Found';

    // Obtain an access token by encoding client details
    final authString = utf8.encode('$clientId:$clientSecret');
    final authStringBase64 = base64.encode(authString);

    // Obtain Access Token at this URL
    try {
      var response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Authorization': 'Basic $authStringBase64',
        },
        body: {
          'grant_type': 'client_credentials',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];

        // Use the access token to search for a track
        final searchResponse = await http.get(
          Uri.https('api.spotify.com', '/v1/search', {
            'q': _searchController.text,
            'type': 'track',
          }),
          headers: {
            'Authorization': 'Bearer $token',
          },
        );

        if (searchResponse.statusCode == 200) {
          final searchData = jsonDecode(searchResponse.body);
          final tracks = searchData['tracks']['items'];
          if (tracks.isNotEmpty) {
            setState(() {
              _trackId = tracks[0]['id'];
              _recommendations = null;
            });
            await _getRecommendations();
          } else {
            throw ('Failed to search for track: ${searchResponse.statusCode}');
          }
        }
      }
    } catch (e) {
      throw ('Failed to obtain access token: $e');
    }
  }

  // Gets recommendations for a track
  Future<void> _getRecommendations() async {
    final clientId = dotenv.env['CLIENT_ID'] ?? 'Client ID not available';
    final clientSecret =
        dotenv.env['CLIENT_SECRET'] ?? 'Client secret not available';

    // Obtain an access token using the Client Credentials Flow
    final authString = utf8.encode('$clientId:$clientSecret');
    final authStringBase64 = base64.encode(authString);

    //Aceess Token URL
    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Authorization': 'Basic $authStringBase64',
      },
      body: {
        'grant_type': 'client_credentials',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['access_token'];

      // Use the access token to get recommendations
      final recommendationsResponse = await http.get(
        Uri.https('api.spotify.com', '/v1/recommendations', {
          'seed_tracks': _trackId,
        }),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (recommendationsResponse.statusCode == 200) {
        final recommendationsData = jsonDecode(recommendationsResponse.body);
        final tracks = recommendationsData['tracks'];
        setState(() {
          _recommendations = tracks;
        });
      } else {
        throw ('Failed to get recommendations: ${recommendationsResponse.statusCode}');
      }
    } else {
      throw ('Failed to obtain access token: t${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Container(
        margin: const EdgeInsets.only(right: 8.0, bottom: 8.0),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FavoritesScreen()),
            );
          },
          backgroundColor: const Color(0xFFD14853),
          icon: const Icon(Icons.my_library_music_outlined),
          label: const Text("Favorites"),
        ),
      ),
      appBar: AppBar(
        title: const Text('Tunistic'),
      ),
      body: IndexedStack(
        index: currentIndex,
        textDirection: TextDirection.ltr,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter a music track',
                    hintStyle: const TextStyle(
                      color: Colors.white,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.search,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: _searchTrack,
                  child: const Text('Get Recommendations'),
                ),
                const SizedBox(height: 16.0),
                if (_recommendations != null &&
                    _recommendations!.isNotEmpty) ...[
                  const Text(
                    'Recommended Tracks',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _recommendations!.length,
                      itemBuilder: (context, index) {
                        final track = _recommendations![index];
                        return ListTile(
                          leading:
                              Image.network(track['album']['images'][0]['url']),
                          title: Text(
                            track['name'],
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            track['artists'][0]['name'],
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              HeartedSongsProvider.of(context)
                                      .contains(track['id'])
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: const Color(0xFFD14853),
                            ),
                            onPressed: () {
                              HeartedSongsProvider.of(context).toggle(
                                track['id'],
                                track,
                              );
                              setState(() {});
                            },
                          ),
                          onTap: () async {
                            //Play audio preview
                            final track = _recommendations![index];
                            final previewUrl = track['preview_url'];
                            //final tname = track['name'];
                            if (previewUrl != null) {
                              if (playingIndex == index && isPlaying) {
                                await player.stop();
                                isPlaying = false;
                              } else {
                                await player.setUrl(track['preview_url']);
                                player.play();
                                playingIndex = index;
                                isPlaying = true;
                              }
                            } else {
                              // Handle the case where the track doesn't have a preview_url
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Track doesn\'t have an audio preview that can be played'),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
