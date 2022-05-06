import 'dart:core';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class DataChannelSample extends StatefulWidget {
  static String tag = 'data_channel_sample';

  @override
  _DataChannelSampleState createState() => _DataChannelSampleState();
}

class _DataChannelSampleState extends State<DataChannelSample> {
  RTCPeerConnection? _localPeerConnection;
  RTCPeerConnection? _remotePeerConnection;

  bool _inCalling = false;

  RTCDataChannelInit? _dataChannelDict;
  RTCDataChannel? _dataChannel;

  String _sdp = '';

  @override
  void initState() {
    super.initState();
  }

  void _onSignalingState(RTCSignalingState state) {
    print(state);
  }

  void _onIceGatheringState(RTCIceGatheringState state) {
    print(state);
  }

  void _onIceConnectionState(RTCIceConnectionState state) {
    print(state);
  }

  void _onLocalCandidate(RTCIceCandidate candidate) {
    print('onCandidate: ${candidate.candidate}');
    _remotePeerConnection?.addCandidate(candidate);
    setState(() {
      _sdp += '\n';
      _sdp += candidate.candidate ?? '';
    });
  }

  void _onRemoteCandidate(RTCIceCandidate candidate) {
    print('onCandidate: ${candidate.candidate}');
    _localPeerConnection?.addCandidate(candidate);
    setState(() {
      _sdp += '\n';
      _sdp += candidate.candidate ?? '';
    });
  }

  void _onRenegotiationNeeded() {
    print('RenegotiationNeeded');
  }

  /// Send some sample messages and handle incoming messages.
  void _onDataChannel(RTCDataChannel dataChannel) async {
    dataChannel.onMessage = (message) {
      if (message.type == MessageType.text) {
        print(message.text);
      } else {
        // do something with message.binary
      }
    };
    // or alternatively:
    dataChannel.messageStream.listen((message) {
      if (message.type == MessageType.text) {
        print(message.text);
      } else {
        // do something with message.binary
      }
    });

    dataChannel.bufferedAmountStream.listen((event) {
      _sdp += '\n BufferedAmountChanged called!';
    });

    await dataChannel.send(RTCDataChannelMessage('Hello!'));

    await dataChannel
        .send(RTCDataChannelMessage.fromBinary(Uint8List.fromList([5, 0, 5])));

    var bufferedAmount = await dataChannel.bufferedAmount;
    _sdp += '\n bufferedAmount: $bufferedAmount';
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  void _makeCall() async {
    _sdp = '';
    var configuration = <String, dynamic>{
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
      ]
    };

    final offerSdpConstraints = <String, dynamic>{
      'mandatory': {
        'OfferToReceiveAudio': false,
        'OfferToReceiveVideo': false,
      },
      'optional': [],
    };

    final loopbackConstraints = <String, dynamic>{
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };

    if (_localPeerConnection != null) return;

    try {
      _localPeerConnection =
          await createPeerConnection(configuration, loopbackConstraints);
      _remotePeerConnection =
          await createPeerConnection(configuration, loopbackConstraints);

      _localPeerConnection!.onSignalingState = _onSignalingState;
      _localPeerConnection!.onIceGatheringState = _onIceGatheringState;
      _localPeerConnection!.onIceConnectionState = _onIceConnectionState;
      _localPeerConnection!.onIceCandidate = _onLocalCandidate;
      _localPeerConnection!.onRenegotiationNeeded = _onRenegotiationNeeded;

      _remotePeerConnection!.onSignalingState = _onSignalingState;
      _remotePeerConnection!.onIceGatheringState = _onIceGatheringState;
      _remotePeerConnection!.onIceConnectionState = _onIceConnectionState;
      _remotePeerConnection!.onIceCandidate = _onRemoteCandidate;
      _remotePeerConnection!.onRenegotiationNeeded = _onRenegotiationNeeded;
      _remotePeerConnection!.onDataChannel = _onDataChannel;
      _dataChannelDict = RTCDataChannelInit();
      _dataChannelDict!.id = 1;
      _dataChannelDict!.ordered = true;
      _dataChannelDict!.maxRetransmitTime = -1;
      _dataChannelDict!.maxRetransmits = -1;
      _dataChannelDict!.protocol = 'sctp';
      _dataChannelDict!.negotiated = false;

      _dataChannel = await _localPeerConnection!
          .createDataChannel('dataChannel', _dataChannelDict!);
      _dataChannel!.onMessage = (data) => {
            setState(() {
              _sdp += "\n";
              _sdp += data.text;
            })
          };

      var localDescription =
          await _localPeerConnection!.createOffer(offerSdpConstraints);
      print(localDescription.sdp);
      await _localPeerConnection!.setLocalDescription(localDescription);

      await _remotePeerConnection!.setRemoteDescription(localDescription);
      var remoteDescription =
          await _remotePeerConnection!.createAnswer(offerSdpConstraints);
      await _remotePeerConnection!.setLocalDescription(remoteDescription);
      await _localPeerConnection!.setRemoteDescription(remoteDescription);
    } catch (e) {
      print(e.toString());
    }
    if (!mounted) return;

    setState(() {
      _inCalling = true;
    });
  }

  void _hangUp() async {
    try {
      await _dataChannel?.close();
      await _localPeerConnection?.close();
      _localPeerConnection = null;
    } catch (e) {
      print(e.toString());
    }
    setState(() {
      _inCalling = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Data Channel Test'),
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          return Center(
            child: Container(
              child: _inCalling ? Text(_sdp) : Text('data channel test'),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _inCalling ? _hangUp : _makeCall,
        tooltip: _inCalling ? 'Hangup' : 'Call',
        child: Icon(_inCalling ? Icons.call_end : Icons.phone),
      ),
    );
  }
}
