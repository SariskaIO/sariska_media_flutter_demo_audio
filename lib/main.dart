import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sariska_media_flutter_sdk/Conference.dart';
import 'package:sariska_media_flutter_sdk/Connection.dart';
import 'package:sariska_media_flutter_sdk/JitsiLocalTrack.dart';
import 'package:sariska_media_flutter_sdk/JitsiRemoteTrack.dart';
import 'package:sariska_media_flutter_sdk/SariskaMediaTransport.dart';
import 'package:sariska_media_flutter_demo_audio/GenerateToken.dart';

typedef void LocalTrackCallback(List<JitsiLocalTrack> tracks);

void main() {
  runApp(
    MaterialApp(
      home: RoomNamePage(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key, required this.roomName}) : super(key: key);

  final String roomName;

  @override
  State<MyApp> createState() => _MyAppState();
  static late LocalTrackCallback localTrackCallback;
}

class _MyAppState extends State<MyApp> {
  final _sariskaMediaTransport = SariskaMediaTransport();
  String token = 'unknown';
  String streamURL = '';
  List<JitsiRemoteTrack> remoteTracks = [];
  List<JitsiLocalTrack> localtracks = [];

  JitsiLocalTrack? localTrack;
  bool isAudioOn = true;
  bool isSpeakerOn = false;

  late Conference _conference;
  late Connection _connection;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          children: [
            if (localTrack != null)
              Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.black,
                    child: const Icon(
                      IconlyLight.profile,
                      color: Colors.white,
                      size: 100.0,
                    ),
                  )),
            Positioned(
              bottom: 140,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: remoteTracks.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 2.0, right: 2.0),
                      child: Container(
                        width: 120,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: index % 2 == 0
                              ? Colors.deepPurple.withAlpha(100)
                              : Colors.redAccent.withAlpha(100),
                        ),
                        child: Icon(
                          IconlyLight.user3,
                          color: index % 2 == 0
                              ? Colors.deepPurple
                              : Colors.redAccent,
                          size: 20.0,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Material(
                    borderRadius: BorderRadius.circular(30),
                    clipBehavior: Clip.antiAlias,
                    color: Colors.transparent,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaY: 20,
                        sigmaX: 20,
                      ),
                      child: InkWell(
                        highlightColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 20,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              buildCustomButton(
                                onPressed: () {
                                  setState(() {
                                    for (JitsiLocalTrack track in localtracks) {
                                      if (track.getType() == "audio") {
                                        if (isAudioOn) {
                                          track.mute();
                                          isAudioOn = !isAudioOn;
                                        } else {
                                          track.unmute();
                                          isAudioOn = !isAudioOn;
                                        }
                                        break;
                                      }
                                    }
                                  });
                                },
                                icon: isAudioOn
                                    ? IconlyLight.voice
                                    : Icons.mic_off_outlined,
                                color: Colors.transparent,
                              ),
                              buildEndCallButton(
                                onPressed: () {
                                  print("Ending call");
                                  _conference.leave();
                                  _connection.disconnect();
                                  exit(0);
                                },
                              ),
                              buildCustomButton(
                                onPressed: () async {
                                  if (isSpeakerOn) {
                                    toggleSpeaker(false);
                                  } else {
                                    toggleSpeaker(true);
                                  }
                                },
                                icon: isSpeakerOn
                                    ? IconlyLight.volumeUp
                                    : IconlyBold.volumeOff,
                                color: Colors.transparent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
      ),
    );
  }

  Future<void> initPlatformState() async {
    try {
      token = await generateToken();

      _sariskaMediaTransport.initializeSdk();

      setupLocalStream();

      _connection = Connection(token, widget.roomName, false);

      _connection.addEventListener("CONNECTION_ESTABLISHED", () {
        _conference = _connection.initJitsiConference();

        _conference.addEventListener("CONFERENCE_JOINED", () {
          print("Conference joined from Swift and Android");
          print(localtracks.length);
          for (JitsiLocalTrack track in localtracks) {
            print(track.getType());
            _conference.addTrack(track);
          }
        });

        _conference.addEventListener("TRACK_ADDED", (track) {
          JitsiRemoteTrack remoteTrack = track;
          for (JitsiLocalTrack track in localtracks) {
            if (track.getStreamURL() == remoteTrack.getStreamURL()) {
              return;
            }
          }
          if (remoteTrack.getType() == "video") {
            return;
          }
          streamURL = remoteTrack.getStreamURL();
          replaceChild(remoteTrack);
        });

        _conference.join();
      });

      _connection.addEventListener("CONNECTION_FAILED", () {
        print("Connection Failed");
      });

      _connection.addEventListener("CONNECTION_DISCONNECTED", () {
        print("Connection Disconnected");
      });

      _connection.connect();

      setState(() {});
    } on PlatformException {
      print("Failed to get platform version.");
    }
  }

  void setupLocalStream() {
    Map<String, dynamic> options = {};
    options["audio"] = true;
    options["video"] = false;

    _sariskaMediaTransport.createLocalTracks(options, (tracks) {
      print("Soniye");
      localtracks = tracks;
      for (JitsiLocalTrack track in localtracks) {
        if (track.getType() == "audio") {
          setState(() {
            localTrack = track;
          });
        }
      }
    });
  }

  void replaceChild(JitsiRemoteTrack remoteTrack) {
    setState(() {
      remoteTracks.add(remoteTrack);
    });
  }

  Widget buildCustomButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }

  Widget buildEndCallButton({required VoidCallback onPressed}) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.red,
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(15),
          child: const Icon(
            Icons.call_end,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }

  void toggleSpeaker(bool isSpeaker) async {
    for (JitsiLocalTrack track in localtracks) {
      if (track.getType() == "audio") {
        track.toggleSpeaker(isSpeaker);
        isSpeakerOn = isSpeaker;
        setState(() {});
      }
    }
  }
}

class RoomNamePage extends StatefulWidget {
  const RoomNamePage({Key? key}) : super(key: key);

  @override
  _RoomNamePageState createState() => _RoomNamePageState();
}

class _RoomNamePageState extends State<RoomNamePage> {
  final TextEditingController _roomNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    webViewMethod();
  }

  Future webViewMethod() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Permission.microphone.request();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency, // or any other theme configuration
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Enter Room Name'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _roomNameController,
                decoration: const InputDecoration(labelText: 'Room Name'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final roomName = _roomNameController.text.trim();
                  if (roomName.isNotEmpty) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MyApp(roomName: roomName),
                      ),
                    );
                  }
                },
                child: const Text('Enter Room'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
