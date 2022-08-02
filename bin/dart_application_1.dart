
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:async/async.dart';
import 'package:sprintf/sprintf.dart';

class Instruction
{
  final int code;
  final String api;
  final SendPort responsePort;
  const Instruction(this.code,this.api,this.responsePort);

}

class Result
{
  final int code;
  final Object value;
  const Result(this.code,this.value);

}

class CityCord 
{

  final double lat;
  final double lon;

  const CityCord({required this.lat, required this.lon});
  factory CityCord.fromJson(Map<String, dynamic> json)  
  {
    return CityCord(lat : double.parse(json['lat']),lon :  double.parse(json['lon']));
  }

}

void main(List<String> arguments) async {
   
  const String apiCallCityCoordTemplate  = "https://nominatim.openstreetmap.org/search?city=%s&format=json&limit=1";
  const String apiCallMeteoCoordTemplate = "https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s&hourly=temperature_2m,apparent_temperature,rain,windspeed_10m";
 
  String city = 'Rovereto';
  String? apiCallCityCoord = sprintf(apiCallCityCoordTemplate, [city]);
  String? apiCallMeteoCoord;
  CityCord? rovereto;

  //ISOLATE
  final mainReceivePort = ReceivePort();
  final exitPort = ReceivePort();
  //SENDPORT OF RECEIVER IS THE BACKCHANNELL WHOME THE THE ISOLAT HAS TO WRITE
  Isolate.spawn(workerDeserializeNetworkCall, mainReceivePort.sendPort,onExit: exitPort.sendPort);
  
  //FIRST MESSAGE OF THE worker is his sendPort
  SendPort childSendPort    = await mainReceivePort.first;

  ReceivePort responsePort1 = ReceivePort();
  ReceivePort responsePort2 = ReceivePort();

  childSendPort.send(Instruction(0,apiCallCityCoord,responsePort1.sendPort));

  rovereto = await responsePort1.first;
  
  print(rovereto?.lat);
  print(rovereto?.lon);
  if(rovereto!=null)
  {
  String latS = rovereto.lat.toString();
  String lonS = rovereto.lon.toString();
  apiCallMeteoCoord = sprintf(apiCallMeteoCoordTemplate,[latS,lonS]);

  childSendPort.send(Instruction(1,apiCallMeteoCoord,responsePort2.sendPort));
  }

  var message = await responsePort2.first;

  if(message is Map<String,dynamic>)
  {
     print(message);
  }

   childSendPort.send(null);
   var exitMessage = await exitPort.first;
   print(exitMessage);
  
}

Future<http.Response> fetchFutureData(String uri) {
  return http.get(Uri.parse(uri));
}

Future<void> workerDeserializeNetworkCall(SendPort mainSendPort) async
{
  final commandPort = ReceivePort();
  mainSendPort.send(commandPort.sendPort);

  
  await for(var message in commandPort)
  {

 if (message == null) 
    {
       Isolate.exit();
    }
   else 
   {
     message = message as Instruction;
   }

  if (message.code == 0)
  { 
  final http.Response cityCordResponse =  await fetchFutureData(message.api);
  CityCord? cityCord;

  if(cityCordResponse.statusCode == 200)
  {
    print(cityCordResponse.body);
    final List jsonresponses = json.decode(cityCordResponse.body);
    cityCord =  CityCord.fromJson(jsonresponses[0]);
  }
  
  message.responsePort.send(cityCord);
  continue;
  }


  if (message.code == 1)
  {
     final http.Response meteoAtCordResponse =  await fetchFutureData(message.api);
     Map<String,dynamic>? meteoMap;

     if(meteoAtCordResponse.statusCode == 200)
     {
          print(meteoAtCordResponse.body);
          meteoMap = jsonDecode(meteoAtCordResponse.body);
     }
      message.responsePort.send(meteoMap);
    continue;
  }
   
  //Isolate.exit(p,cityCord);
  }

  }


