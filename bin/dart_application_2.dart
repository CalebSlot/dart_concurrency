

import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:async/async.dart';
import 'package:sprintf/sprintf.dart';

class Command
{
  final int code;
  final String? api;
  final SendPort responsePort;
  const Command(this.code,this.responsePort,[this.api]);
  void send(SendPort sendPort,Object? message)
  {
    sendPort.send(message);
  }
  void reply(Object? message)
  {
    responsePort.send(message);
  }
  
}
class Response
{
  final int code;
  final Object? value;
  const Response(this.code,this.value);
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

void main(List<String> arguments) async
{
  const String apiCallCityCoordTemplate  = "https://nominatim.openstreetmap.org/search?city=%s&format=json&limit=1";
  const String apiCallMeteoCoordTemplate = "https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s&hourly=temperature_2m,apparent_temperature,rain,windspeed_10m";
  String city = 'Rovereto';
  String? apiCallCityCoord = sprintf(apiCallCityCoordTemplate, [city]);
  String? apiCallMeteoCoord;
  CityCord? rovereto;

//ISOLATE
  final mainReceivePort = ReceivePort();
  final exitPort = ReceivePort();

  Isolate.spawn(workerDeserializeNetworkCall, mainReceivePort.sendPort,onExit: exitPort.sendPort);

  SendPort? childSendPort    = null;

  await for(Response response in mainReceivePort)
  {
   if (response.code == -2) 
    {
      print(response.value);
      print("QUITTING");
      break;
    }
   
    if(response.code == -1)
    {
      childSendPort = response.value as SendPort;
      childSendPort.send(Command(0,mainReceivePort.sendPort,apiCallCityCoord));
      continue;
    }
    if(response.code == 0)
    {
      if(response.value!=null)
      {
      rovereto = response.value as CityCord;
      print(rovereto.lat);
      print(rovereto.lon);
 
         String latS = rovereto.lat.toString();
         String lonS = rovereto.lon.toString();
         apiCallMeteoCoord = sprintf(apiCallMeteoCoordTemplate,[latS,lonS]);
         childSendPort?.send(Command(1,mainReceivePort.sendPort,apiCallMeteoCoord));
     }
      continue;
    }
     if(response.code == 1)
    {
      var meteo = response.value as Map<String,dynamic>;
      print(meteo);
      childSendPort?.send(Command(-2,mainReceivePort.sendPort));
      continue;
    }
  }
  var onexit = await exitPort.firstOrNull;
  print(onexit);

}









Future<http.Response> fetchFutureData(String uri) {
  return http.get(Uri.parse(uri));
}

Future<void> workerDeserializeNetworkCall(SendPort mainSendPort) async
{
  final commandPort = ReceivePort();
  mainSendPort.send(Response(-1,commandPort.sendPort));

  
  await for(var message in commandPort)
  {

 if (message.code == -2) 
    {
       message.reply(Response(message.code,"GOODBYE!"));
       Isolate.exit();
    }

  if (message.code == 0)
  { 
  final http.Response cityCordResponse =  await fetchFutureData(message.api??"");
  CityCord? cityCord;

  if(cityCordResponse.statusCode == 200)
  {
    print(cityCordResponse.body);
    final List jsonresponses = json.decode(cityCordResponse.body);
    cityCord =  CityCord.fromJson(jsonresponses[0]);
  }
  
  message.reply(Response(message.code,cityCord));
  continue;
  }


  if (message.code == 1)
  {
     final http.Response meteoAtCordResponse =  await fetchFutureData(message.api??"");
     Map<String,dynamic>? meteoMap;

     if(meteoAtCordResponse.statusCode == 200)
     {
          print(meteoAtCordResponse.body);
          meteoMap = jsonDecode(meteoAtCordResponse.body);
     }

    message.reply(Response(message.code,meteoMap));
    continue;
  }
   
  //Isolate.exit(p,cityCord);
  }

  }