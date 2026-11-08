import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hyzen_pharmd/features/study_progress/study_forms.dart';
import 'package:hyzen_pharmd/features/study_progress/study_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('task edits preserve identity and cancel makes no writes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final tracker = StudyTracker(prefs,'forms',(_){},scheduleDevice:false);
    addTearDown(tracker.dispose);
    tracker.saveTask(const StudyTask('stable-id','Original',done:true));
    await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>Scaffold(body:TextButton(
      onPressed:()=>showStudyForm(context,tracker,existing:tracker.tasks.single),child:const Text('Edit'))))));
    await tester.tap(find.text('Edit')); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first,'Changed');
    await tester.enterText(find.byType(TextFormField).at(2),'47');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes')); await tester.pumpAndSettle();
    expect(tracker.tasks.single.id,'stable-id');
    expect(tracker.tasks.single.title,'Changed');
    expect(tracker.tasks.single.done,isTrue);
    expect(tracker.tasks.single.estimatedMinutes,47);
    await tester.tap(find.text('Edit')); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first,'Not saved');
    Navigator.pop(tester.element(find.byType(TextFormField).first));
    await tester.pumpAndSettle();
    expect(tracker.tasks.single.title,'Changed');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for(final reminder in [false,true]) {
    testWidgets('${reminder ? 'reminder' : 'task'} sheet at 320px and double text', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final tracker=StudyTracker(await SharedPreferences.getInstance(),'layout',(_){},scheduleDevice:false);
      addTearDown(tracker.dispose);
      tester.view.physicalSize=const Size(320,844);tester.view.devicePixelRatio=1;
      tester.platformDispatcher.textScaleFactorTestValue=2;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>Scaffold(body:TextButton(
        onPressed:()=>showStudyForm(context,tracker,reminder:reminder),child:const Text('Open'))))));
      await tester.tap(find.text('Open'));await tester.pumpAndSettle();
      for(var i=0;i<8;i++) {
        await tester.drag(find.byType(SingleChildScrollView).first,const Offset(0,-400));
        await tester.pumpAndSettle();expect(tester.takeException(),isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
