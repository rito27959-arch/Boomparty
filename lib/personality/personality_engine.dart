import 'dart:math' as math;

import '../character/bomb_state.dart';

/// Événements de jeu auxquels la bombe réagit (BOOM PERSONALITY ENGINE).
enum ReactionEvent {
  gameStart,
  roundStart,
  yourTurn,
  accepted,
  acceptedFast,
  acceptedStreak,
  duplicate,
  duplicateSynonym,
  wrongCategory,
  unknown,
  ambiguous,
  recognitionError,
  hurry,
  explosion,
  roundEnd,
  gameEnd,
}

enum PersonalityId { classic, crazy, drama }

/// Une réplique : texte avec variables ({name}, {word}, {prev}, {category},
/// {alt}), émotion (→ animation) et identifiant stable (→ fichier audio
/// prégénéré si le texte ne contient aucune variable).
class Line {
  const Line(this.id, this.text, this.emotion);
  final String id;
  final String text;
  final BombState emotion;

  bool get isStatic => !text.contains('{');
}

class Reaction {
  const Reaction({required this.line, required this.text, required this.emotion, required this.event});
  final Line line;
  final String text; // texte final (variables remplacées)
  final BombState emotion;
  final ReactionEvent event;
}

/// Contexte fourni par le moteur de jeu.
class ReactionContext {
  const ReactionContext({this.name, this.word, this.previous, this.category, this.alternatives = const [], this.streak = 0});
  final String? name, word, previous, category;
  final List<String> alternatives;
  final int streak;
}

class PersonalityEngine {
  PersonalityEngine({this.profile = PersonalityId.classic, math.Random? random}) : _rng = random ?? math.Random();

  PersonalityId profile;
  final math.Random _rng;

  /// Historique des répliques récentes : on évite de les répéter.
  final List<String> _recent = [];
  static const _memory = 6;

  Reaction react(ReactionEvent e, [ReactionContext ctx = const ReactionContext()]) {
    final pool = (lines[profile]![e] ?? lines[PersonalityId.classic]![e])!;
    // pondération : les répliques récentes deviennent très improbables
    // la dernière réplique n'est jamais rejouée tout de suite (si le choix existe)
    final last = _recent.isEmpty ? null : _recent.last;
    final weights = [
      for (final l in pool)
        pool.length > 1 && l.id == last
            ? 0.0
            : _recent.contains(l.id)
                ? 0.05
                : 1.0,
    ];
    var r = _rng.nextDouble() * weights.reduce((a, b) => a + b);
    var pick = pool[weights.lastIndexWhere((w) => w > 0)];
    for (var i = 0; i < pool.length; i++) {
      if (weights[i] == 0) continue;
      r -= weights[i];
      if (r <= 0) {
        pick = pool[i];
        break;
      }
    }
    _recent.add(pick.id);
    if (_recent.length > _memory) _recent.removeAt(0);
    return Reaction(line: pick, text: _fill(pick.text, ctx), emotion: pick.emotion, event: e);
  }

  int poolSize(ReactionEvent e) => (lines[profile]![e] ?? lines[PersonalityId.classic]![e])!.length;

  static String _fill(String t, ReactionContext c) => t
      .replaceAll('{name}', c.name ?? '')
      .replaceAll('{word}', c.word ?? '')
      .replaceAll('{prev}', c.previous ?? '')
      .replaceAll('{category}', c.category ?? '')
      .replaceAll('{alt}', c.alternatives.join(' ou '))
      .replaceAll('{streak}', '${c.streak}');

  /// Toutes les répliques sans variable (pour la prégénération audio).
  static Iterable<(PersonalityId, Line)> staticLines() sync* {
    for (final p in lines.entries) {
      for (final pool in p.value.values) {
        for (final l in pool) {
          if (l.isStatic) yield (p.key, l);
        }
      }
    }
  }

  static const _h = BombState.happy, _l = BombState.laughing, _a = BombState.angry, _c = BombState.confused;
  static const _p = BombState.panic, _t = BombState.talking, _x = BombState.explosion, _cel = BombState.celebration;
  static const _th = BombState.thinking;

  static const Map<PersonalityId, Map<ReactionEvent, List<Line>>> lines = {
    PersonalityId.classic: {
      ReactionEvent.gameStart: [
        Line('c_gs1', 'Bienvenue à BOOM PARTY ! Que la soirée commence !', _cel),
        Line('c_gs2', 'Installez-vous, ça va chauffer !', _h),
      ],
      ReactionEvent.roundStart: [
        Line('c_rs1', 'Bon, mes petits génies ! Catégorie : {category} ! {name}, commence !', _t),
        Line('c_rs2', 'Nouvelle manche ! {category} ! {name}, à toi l\'honneur !', _t),
        Line('c_rs3', 'On va voir qui s\'y connaît en {category} ! {name}, vas-y !', _t),
      ],
      ReactionEvent.yourTurn: [
        Line('c_yt1', 'À toi, {name} !', _t),
        Line('c_yt2', '{name}, c\'est ton tour !', _t),
        Line('c_yt3', 'Allez {name} !', _t),
      ],
      ReactionEvent.accepted: [
        Line('c_ok1', 'Excellent ! C\'est validé !', _h),
        Line('c_ok2', 'OUI ! Bien joué !', _h),
        Line('c_ok3', 'Parfait !', _h),
        Line('c_ok4', 'Validé ! Au suivant !', _h),
        Line('c_ok5', 'Bien vu !', _h),
      ],
      ReactionEvent.acceptedFast: [
        Line('c_of1', 'Bien joué ! Franchement, je ne m\'attendais pas à ça !', _h),
        Line('c_of2', 'Rapide comme l\'éclair !', _cel),
      ],
      ReactionEvent.acceptedStreak: [
        Line('c_st1', 'Quelle série ! Vous êtes en feu !', _cel),
        Line('c_st2', 'Ça enchaîne ! J\'adore !', _cel),
      ],
      ReactionEvent.duplicate: [
        Line('c_du1', 'Ah non ! Pas encore ce mot !', _a),
        Line('c_du2', '{word} ? Déjà dit ! Cherche autre chose !', _a),
        Line('c_du3', 'Hop hop hop ! Celui-là, on l\'a déjà !', _a),
      ],
      ReactionEvent.duplicateSynonym: [
        Line('c_ds1', 'AHAHA ! Tu pensais vraiment m\'avoir ? {word}, {prev}, c\'est exactement la même chose !', _l),
        Line('c_ds2', 'Bien essayé ! Mais {word} et {prev}, c\'est pareil !', _l),
      ],
      ReactionEvent.wrongCategory: [
        Line('c_wc1', '{word} ?! Dans la catégorie {category} ?! Tu es sûr de toi ?', _c),
        Line('c_wc2', 'Mais qu\'est-ce que tu racontes ?! {word}, ça n\'a rien à voir !', _c),
        Line('c_wc3', 'Hmm… {word}, ce n\'est pas vraiment {category} !', _c),
      ],
      ReactionEvent.unknown: [
        Line('c_un1', 'Je ne connais pas ce mot-là… Essaie autre chose !', _c),
        Line('c_un2', 'Ça existe, ça ? Propose autre chose !', _c),
      ],
      ReactionEvent.ambiguous: [
        Line('c_am1', 'Attends… tu veux dire {alt} ?', _th),
      ],
      ReactionEvent.recognitionError: [
        Line('c_re1', 'Je n\'ai pas bien entendu ! Répète !', _th),
        Line('c_re2', 'Pardon ? Un peu plus fort !', _th),
      ],
      ReactionEvent.hurry: [
        Line('c_hu1', 'Dépêche-toi !', _p),
        Line('c_hu2', 'Ouh là là… Ça sent mauvais !', _p),
        Line('c_hu3', 'Trop lent… ça va exploser !', _p),
      ],
      ReactionEvent.explosion: [
        Line('c_ex1', 'BOOOOOOOM !', _x),
        Line('c_ex2', 'BOOOM ! Trop tard !', _x),
      ],
      ReactionEvent.roundEnd: [
        Line('c_re_1', 'Alors, qui veut sa revanche ?', _t),
        Line('c_re_2', 'On remet ça ?', _t),
      ],
      ReactionEvent.gameEnd: [
        Line('c_ge1', 'Bravo {name} ! Soirée de légende !', _cel),
        Line('c_ge2', 'Et la victoire revient à {name} ! Bravo !', _cel),
      ],
    },
    PersonalityId.crazy: {
      ReactionEvent.gameStart: [
        Line('z_gs1', 'YAAAAH ! C\'EST PARTI POUR LE CHAOS !', _cel),
        Line('z_gs2', 'Attachez vos ceintures, je suis une BOMBE !', _l),
      ],
      ReactionEvent.roundStart: [
        Line('z_rs1', '{category} ! {category} ! {name}, FONCE !', _t),
        Line('z_rs2', 'Catégorie… {category} ! {name}, ne me déçois pas !', _t),
      ],
      ReactionEvent.yourTurn: [
        Line('z_yt1', '{name} ! VITE VITE VITE !', _t),
        Line('z_yt2', 'À TOI {name} !', _t),
      ],
      ReactionEvent.accepted: [
        Line('z_ok1', 'OUIIII ! INCROYABLE !', _cel),
        Line('z_ok2', 'BOUM ! Euh non, VALIDÉ !', _l),
        Line('z_ok3', 'C\'EST ÇA ! C\'EST EXACTEMENT ÇA !', _h),
        Line('z_ok4', 'Waouh waouh waouh !', _h),
      ],
      ReactionEvent.acceptedFast: [
        Line('z_of1', 'QUOIIII ?! MAIS COMMENT TU AS TROUVÉ ÇA AUSSI VITE ?!', _cel),
      ],
      ReactionEvent.acceptedStreak: [
        Line('z_st1', 'ENCORE ! ENCORE ! ENCORE !', _cel),
      ],
      ReactionEvent.duplicate: [
        Line('z_du1', 'NON NON NON ! DÉJÀ DIT !', _a),
        Line('z_du2', '{word} ?! ENCORE ?! Ma mèche n\'en peut plus !', _a),
      ],
      ReactionEvent.duplicateSynonym: [
        Line('z_ds1', 'HAHAHA ! {word}, {prev}, MÊME COMBAT ! Bien tenté !', _l),
      ],
      ReactionEvent.wrongCategory: [
        Line('z_wc1', 'UN {word} ?! Mais tu joues à quel jeu exactement ?!', _c),
        Line('z_wc2', '{word} ?! Dans {category} ?! J\'EXPLOSE DE RIRE !', _l),
      ],
      ReactionEvent.unknown: [
        Line('z_un1', 'C\'est quoi ce mot ?! Tu l\'as inventé ?!', _c),
      ],
      ReactionEvent.ambiguous: [
        Line('z_am1', '{alt} ?! Choisis, choisis !', _th),
      ],
      ReactionEvent.recognitionError: [
        Line('z_re1', 'Hein ?! Quoi ?! Répète !', _th),
      ],
      ReactionEvent.hurry: [
        Line('z_hu1', 'ÇA VA PÉTER ! ÇA VA PÉTER !', _p),
        Line('z_hu2', 'Tic tac tic tac ! PLUS VITE !', _p),
      ],
      ReactionEvent.explosion: [
        Line('z_ex1', 'BOOOOOOOOOOOOM ! HAHAHA !', _x),
      ],
      ReactionEvent.roundEnd: [
        Line('z_re_1', 'ENCORE UNE ! ENCORE UNE !', _l),
      ],
      ReactionEvent.gameEnd: [
        Line('z_ge1', '{name} EST LE ROI DE LA SOIRÉE ! YAAAAH !', _cel),
      ],
    },
    PersonalityId.drama: {
      ReactionEvent.gameStart: [
        Line('d_gs1', 'Mesdames et messieurs… bienvenue au spectacle le plus explosif de la soirée !', _t),
      ],
      ReactionEvent.roundStart: [
        Line('d_rs1', 'Le destin a choisi… {category}. {name}, la scène est à toi.', _t),
        Line('d_rs2', 'Silence dans la salle… {category} ! {name}, commence.', _t),
      ],
      ReactionEvent.yourTurn: [
        Line('d_yt1', '{name}… le monde entier te regarde.', _t),
        Line('d_yt2', 'À toi, {name}. Ne tremble pas.', _t),
      ],
      ReactionEvent.accepted: [
        Line('d_ok1', 'Magnifique. Tout simplement magnifique.', _h),
        Line('d_ok2', 'Le public est en larmes. Validé !', _h),
        Line('d_ok3', 'Bravo ! Quelle élégance !', _h),
      ],
      ReactionEvent.acceptedFast: [
        Line('d_of1', 'Quelle vitesse ! Je n\'avais jamais vu ça de toute ma carrière !', _cel),
      ],
      ReactionEvent.acceptedStreak: [
        Line('d_st1', 'Nous assistons à un moment historique !', _cel),
      ],
      ReactionEvent.duplicate: [
        Line('d_du1', 'Hélas… ce mot a déjà été prononcé. Quelle tragédie !', _a),
        Line('d_du2', 'Non… pas ça. Pas encore {word}.', _a),
      ],
      ReactionEvent.duplicateSynonym: [
        Line('d_ds1', 'Tu croyais me tromper ? {word}… {prev}… c\'est la même chose, voyons !', _l),
      ],
      ReactionEvent.wrongCategory: [
        Line('d_wc1', 'Mesdames et messieurs… nous assistons actuellement à une catastrophe intellectuelle ! {word} ?!', _c),
        Line('d_wc2', '{word}… dans {category}… mon cœur se brise.', _c),
      ],
      ReactionEvent.unknown: [
        Line('d_un1', 'Ce mot m\'est inconnu… et pourtant j\'ai tout vu.', _c),
      ],
      ReactionEvent.ambiguous: [
        Line('d_am1', 'Un dilemme se pose… {alt} ?', _th),
      ],
      ReactionEvent.recognitionError: [
        Line('d_re1', 'Ta voix s\'est perdue dans la nuit… répète.', _th),
      ],
      ReactionEvent.hurry: [
        Line('d_hu1', 'Le temps s\'écoule… inexorablement…', _p),
        Line('d_hu2', 'Je sens… que la fin est proche !', _p),
      ],
      ReactionEvent.explosion: [
        Line('d_ex1', 'BOOOOOOM ! Ainsi s\'achève cette manche…', _x),
      ],
      ReactionEvent.roundEnd: [
        Line('d_re_1', 'Le rideau tombe… mais le spectacle continue !', _t),
      ],
      ReactionEvent.gameEnd: [
        Line('d_ge1', 'Mesdames et messieurs… votre champion : {name} !', _cel),
      ],
    },
  };
}
