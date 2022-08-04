

import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:async/async.dart';
import 'package:sprintf/sprintf.dart';


class Sender
{
  final int code;
  const Sender(this.code);
  void send(SendPort? sendPort)
  {
    sendPort?.send(this);
  }
}

// ignore: non_constant_identifier_names
class Command extends Sender
{

  final String? api;
  final SendPort responsePort;
  const Command(int code,this.responsePort,[this.api]) : super(code);
  
}
class Response extends Sender
{
  final Object? value;
  const Response(int code,this.value) : super(code);
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
  final exitPort        = ReceivePort();

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
      Command(0,mainReceivePort.sendPort,apiCallCityCoord).send(childSendPort);
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
         Command(1,mainReceivePort.sendPort,apiCallMeteoCoord).send(childSendPort);
     }
      continue;
    }
     if(response.code == 1)
    {
      var meteo = response.value as Map<String,dynamic>;
      print(meteo);
      Command(-2,mainReceivePort.sendPort).send(childSendPort);
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
  Response(-1,commandPort.sendPort).send(mainSendPort);

  
  await for(var message in commandPort)
  {

 if (message.code == -2) 
    {
       Response(message.code,"GOODBYE!").send(message.responsePort);
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
  
  Response(message.code,cityCord).send(message.responsePort);
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

    Response(message.code,meteoMap).send(message.responsePort);
    continue;
    
  }
   
  //Isolate.exit(p,cityCord);
  }

  }