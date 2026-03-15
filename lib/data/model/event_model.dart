class EventModel {
  final String pname;
  final String date;

  EventModel({
    required this.pname,
    required this.date,
  });

  EventModel.fromMap(Map<String, dynamic> res)
      : pname = res['pname'],
        date = res['date'];
}