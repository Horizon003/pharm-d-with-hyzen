import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/features/study_progress/study_cloud.dart';
import 'package:hyzen_pharmd/features/study_progress/study_session.dart';
class _User extends Fake implements User {}
class _Cloud extends StudyCloud {
  _Cloud():super(_User());
  int calls=0;
  final batches=<List<String>>[];
  @override
  Future<Map<String,dynamic>> call(String method,Map<String,dynamic> data) async {
    calls++;
    final ids=(data['events'] as List).map((e)=>e['id'] as String).toList();
    batches.add(ids);
    if(calls==1) throw StateError('offline');
    return {'accepted':calls==2?ids.take(50).toList():ids};
  }
}
void main(){
  testWidgets('200 queued events retry and only acknowledged IDs are removed', (tester) async {
    final now=DateTime(2026,11,7,12);
    final pending=List.generate(200,(i)=>StudyEvent(i.toRadixString(16).padLeft(32,'0'),List.filled(32,'a').join(),
      now.add(Duration(seconds:i)),now.add(Duration(seconds:i+1)),'2026-11-07'));
    final cloud=_Cloud();
    final worker=StudySyncWorker(cloud:cloud,events:()=>pending,
      acknowledge:(ids)async{pending.removeWhere((e)=>ids.contains(e.id));},
      running:()=>false,session:()=>null,onStatus:(_){});
    await tester.pump();
    expect(pending.length,200);
    await tester.pump(const Duration(seconds:10));
    expect(pending.length,150);
    expect(cloud.batches[0],cloud.batches[1]);
    await tester.pump(const Duration(seconds:1));
    expect(pending.length,50);
    await tester.pump(const Duration(seconds:1));
    expect(pending,isEmpty);
    worker.dispose();
  });
}
