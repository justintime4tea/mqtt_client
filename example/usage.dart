/*
 * Package : mqtt_client
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 31/05/2017
 * Copyright :  S.Hamblett
 */

import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:observable/observable.dart';
import 'package:typed_data/typed_data.dart' as typed;

/// An annotated simple subscribe/publish usage example for mqtt_client. Please read in with reference
/// to the MQTT specification. The example is runnable, also refer to test/mqtt_client_broker_test...dart
/// files for separate subscribe/publish tests.
Future<int> main() async {
  /// First create a client, the client is constructed with a broker name, client identifier
  /// and port if needed. The client identifier (short ClientId) is an identifier of each MQTT
  /// client connecting to a MQTT broker. As the word identifier already suggests, it should be unique per broker.
  /// The broker uses it for identifying the client and the current state of the client. If you don’t need a state
  /// to be hold by the broker, in MQTT 3.1.1 you can set an empty ClientId, which results in a connection without any state.
  /// A condition is that clean session connect flag is true, otherwise the connection will be rejected.
  /// The client identifier can be a maximum length of 23 characters. If a port is not specified the standard port
  /// of 1883 is used.
  final MqttClient client = new MqttClient("test.mosquitto.org", "");

  /// Set logging on if needed, defaults to off
  client.logging(true);

  /// Create a connection message to use or use the default one. The default one sets the
  /// client identifier, any supplied username/password, the default keepalive interval(60s)
  /// and clean session, an example of a specific one below.
  final MqttConnectMessage connMess = new MqttConnectMessage()
      .withClientIdentifier("Mqtt_clientUniqueId")
      .keepAliveFor(30)
      .withWillTopic("willtopic")
      .withWillQos(MqttQos.atLeastOnce);
  client.connectionMessage = connMess;

  /// Connect the client, any errors here are communicated by raising of the appropriate exception. Note
  /// in some circumstances the broker will just disconnect us, see the spec about this, we however eill
  /// never send malformed messages.
  try {
    await client.connect();
  } catch (Exception) {
    /// Error handling.....
    client.disconnect();
  }

  /// Check we are connected
  if (client.connectionState == ConnectionState.connected) {
    print("Mosquitto client connected");
  } else {
    print(
        "ERROR Mosquitto client connection failed - disconnecting, state is ${client
            .connectionState}");
    client.disconnect();
  }

  /// Ok, lets try a subscription
  final String topic = "test/hw";
  final ChangeNotifier<MqttReceivedMessage> cn =
  client.listenTo(topic, MqttQos.exactlyOnce);

  /// We get a change notifier object(see the Observable class) which we then listen to to get
  /// notifications of published updates to each subscribed topic, one for each topic, these are
  /// basically standard Dart streams and can be managed as you wish.
  cn.changes.listen((List<MqttReceivedMessage> c) {
    final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
    final String pt =
    MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

    /// The payload is a byte buffer, this will be specific to the topic
    print("Change notification:: payload is <$pt> for topic <$topic>");
  });

  /// Lets publish to a topic, use a high QOS
  // Publish a known topic
  final String pubTopic = "Dart/Mqtt_client/testtopic";
  final typed.Uint8Buffer buff = new typed.Uint8Buffer(5);
  buff[0] = 'h'.codeUnitAt(0);
  buff[1] = 'e'.codeUnitAt(0);
  buff[2] = 'l'.codeUnitAt(0);
  buff[3] = 'l'.codeUnitAt(0);
  buff[4] = 'o'.codeUnitAt(0);
  client.publishMessage(pubTopic, MqttQos.exactlyOnce, buff);

  /// Ok, we will now sleep a while, in this gap you will see ping request/response
  /// messages being exchanged by the keep alive mechanism.
  print("Sleeping....");
  await MqttUtilities.asyncSleep(120);

  /// Finally, unsubscribe and exit gracefully
  print("Unsubscribing");
  client.unsubscribe(topic);

  /// Wait for the unsubscribe message from the broker if you wish.
  await MqttUtilities.asyncSleep(2);
  print("Disconnecting");
  client.disconnect();
  return 0;
}