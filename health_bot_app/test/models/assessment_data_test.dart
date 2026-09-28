import 'package:flutter_test/flutter_test.dart';
import 'package:health_bot_app/models/assessment_data.dart';

void main() {
  group('SymptomDuration', () {
    test('every option carries a day count for the backend', () {
      expect(SymptomDuration.oneDay.days, 1);
      expect(SymptomDuration.twoToThreeDays.days, 3);
      expect(SymptomDuration.fourToSevenDays.days, 5);
      expect(SymptomDuration.overAWeek.days, 10);
    });

    test('the label the form shows resolves to the right option', () {
      // Regression: the form offered "> 1 week" while the converter matched
      // ">1 week", so a week-long illness was sent as a single day and lost
      // its prolonged-symptom risk factor.
      for (final option in SymptomDuration.values) {
        expect(SymptomDuration.fromLabel(option.label), option);
      }
    });

    test('label matching ignores spacing', () {
      expect(SymptomDuration.fromLabel('>1 week'), SymptomDuration.overAWeek);
      expect(SymptomDuration.fromLabel('> 1 week'), SymptomDuration.overAWeek);
      expect(SymptomDuration.fromLabel('>1week'), SymptomDuration.overAWeek);
    });

    test('an unrecognised label falls back to one day', () {
      expect(SymptomDuration.fromLabel('whenever'), SymptomDuration.oneDay);
    });

    test('a long illness reaches the backend as more than one day', () {
      final data = AssessmentData(age: 40, duration: SymptomDuration.overAWeek);
      expect(data.durationDays, 10);
    });
  });

  group('AssessmentData age validation', () {
    test('accepts a plausible age', () {
      expect(AssessmentData.validateAge('34'), isNull);
      expect(AssessmentData.isValidAge('34'), isTrue);
    });

    test('accepts the boundaries', () {
      expect(AssessmentData.validateAge('0'), isNull);
      expect(AssessmentData.validateAge('${AssessmentData.maxAge}'), isNull);
    });

    test('rejects an empty entry rather than assuming one', () {
      expect(AssessmentData.validateAge(''), isNotNull);
      expect(AssessmentData.validateAge('   '), isNotNull);
      expect(AssessmentData.validateAge(null), isNotNull);
    });

    test('rejects non-numeric text', () {
      expect(AssessmentData.validateAge('abc'), isNotNull);
      expect(AssessmentData.validateAge('3.5'), isNotNull);
    });

    test('rejects an implausible age', () {
      expect(AssessmentData.validateAge('999'), isNotNull);
      expect(AssessmentData.validateAge('${AssessmentData.maxAge + 1}'), isNotNull);
    });

    test('rejects a negative age', () {
      expect(AssessmentData.validateAge('-5'), isNotNull);
    });

    test('tolerates surrounding whitespace', () {
      expect(AssessmentData.validateAge(' 42 '), isNull);
    });

    test('every rejection explains itself', () {
      for (final bad in ['', 'abc', '999', '-5']) {
        expect(AssessmentData.validateAge(bad), isNotEmpty);
      }
    });
  });

  group('AssessmentData', () {
    test('serialises the fields the backend expects', () {
      final json = AssessmentData(
        age: 42,
        severity: 7,
        symptoms: 'fever',
        duration: SymptomDuration.fourToSevenDays,
      ).toJson();
      expect(json['age'], 42);
      expect(json['severity'], 7);
      expect(json['symptoms'], 'fever');
      expect(json['duration'], '4-7 days');
    });
  });

  group('ConfidenceBand', () {
    test('parses the backend values', () {
      expect(ConfidenceBand.fromString('likely'), ConfidenceBand.likely);
      expect(ConfidenceBand.fromString('possible'), ConfidenceBand.possible);
      expect(ConfidenceBand.fromString('unclear'), ConfidenceBand.unclear);
    });

    test('treats anything unrecognised as unclear', () {
      expect(ConfidenceBand.fromString(null), ConfidenceBand.unclear);
      expect(ConfidenceBand.fromString('definitely'), ConfidenceBand.unclear);
    });

    test('every band has a human label', () {
      for (final band in ConfidenceBand.values) {
        expect(band.label, isNotEmpty);
      }
    });
  });

  group('AssessmentResult', () {
    AssessmentResult build({String condition = 'Malaria', ConfidenceBand? band}) {
      return AssessmentResult(
        conditionName: condition,
        matchPercentage: 72,
        alternateMatches: const [],
        riskLevel: 'moderate',
        advice: 'Rest',
        confidenceBand: band ?? ConfidenceBand.possible,
      );
    }

    test('derives its label from the band when none is given', () {
      expect(build().confidenceLabel, ConfidenceBand.possible.label);
    });

    test('supplies a default specialist', () {
      expect(build().specialist.name, 'General Physician');
    });

    test('recognises an inconclusive result', () {
      expect(build(condition: '').isInconclusive, isTrue);
      expect(build(condition: 'Unknown').isInconclusive, isTrue);
      expect(build().isInconclusive, isFalse);
    });
  });

  group('SpecialistInfo', () {
    test('reads every field the backend sends', () {
      final info = SpecialistInfo.fromJson(const {
        'name': 'Pulmonologist',
        'description': 'Lungs.',
        'department': 'Pulmonology',
        'priority': 'Immediate',
      });
      expect(info.name, 'Pulmonologist');
      expect(info.department, 'Pulmonology');
      expect(info.priority, 'Immediate');
    });

    test('falls back when fields are missing', () {
      final info = SpecialistInfo.fromJson(const {});
      expect(info.name, 'General Physician');
      expect(info.priority, 'Routine');
    });
  });
}
