/// Catégories et consignes. Les listes servent à valider les réponses
/// reconnues ; elles doivent être enrichies au fil des tests de jeu.
class Category {
  const Category({required this.id, required this.label, required this.prompts});
  final String id;
  final String label;
  final List<Prompt> prompts;
}

class Prompt {
  const Prompt({required this.lead, required this.keyword, required this.tail, required this.words});
  final String lead; // « Cite des »
  final String keyword; // « OBJETS »
  final String tail; // « qu'on trouve dans une maison ! »
  final List<String> words;

  String get sentence => '$lead $keyword $tail';
}

const categories = <Category>[
  Category(id: 'animaux', label: 'Animaux', prompts: [
    Prompt(lead: 'Cite des', keyword: 'ANIMAUX', tail: 'de la ferme !', words: [
      'vache', 'cochon', 'poule', 'coq', 'mouton', 'chèvre', 'cheval', 'âne', 'canard', 'oie', 'dinde', 'lapin',
      'chien', 'chat', 'taureau', 'veau', 'agneau', 'poussin', 'bouc', 'brebis', 'jument', 'poney', 'pintade', 'souris', 'rat',
    ]),
    Prompt(lead: 'Cite des', keyword: 'ANIMAUX', tail: 'sauvages !', words: [
      'lion', 'tigre', 'éléphant', 'girafe', 'zèbre', 'singe', 'gorille', 'ours', 'loup', 'renard', 'crocodile', 'hippopotame',
      'rhinocéros', 'guépard', 'panthère', 'léopard', 'hyène', 'kangourou', 'koala', 'panda', 'serpent', 'aigle', 'cerf',
      'sanglier', 'chimpanzé', 'antilope', 'gazelle', 'buffle', 'jaguar', 'lynx', 'chameau', 'dromadaire', 'autruche',
    ]),
  ]),
  Category(id: 'pays', label: 'Pays', prompts: [
    Prompt(lead: 'Cite des', keyword: 'PAYS', tail: "d'Afrique !", words: [
      'cameroun', 'sénégal', "côte d'ivoire", 'nigeria', 'ghana', 'maroc', 'algérie', 'tunisie', 'égypte', 'mali', 'niger',
      'tchad', 'gabon', 'congo', 'kenya', 'éthiopie', 'afrique du sud', 'angola', 'bénin', 'togo', 'burkina faso', 'guinée',
      'madagascar', 'rwanda', 'burundi', 'ouganda', 'tanzanie', 'zambie', 'zimbabwe', 'mozambique', 'namibie', 'botswana',
      'libye', 'soudan', 'somalie', 'mauritanie', 'centrafrique', 'liberia', 'sierra leone', 'gambie', 'cap vert', 'malawi',
    ]),
    Prompt(lead: 'Cite des', keyword: 'PAYS', tail: "d'Europe !", words: [
      'france', 'allemagne', 'espagne', 'italie', 'portugal', 'belgique', 'suisse', 'pays bas', 'luxembourg', 'autriche',
      'pologne', 'grèce', 'suède', 'norvège', 'danemark', 'finlande', 'irlande', 'royaume uni', 'angleterre', 'écosse',
      'roumanie', 'hongrie', 'bulgarie', 'croatie', 'serbie', 'ukraine', 'russie', 'tchéquie', 'slovaquie', 'islande', 'malte',
    ]),
  ]),
  Category(id: 'objets', label: 'Objets', prompts: [
    Prompt(lead: 'Cite des', keyword: 'OBJETS', tail: "qu'on trouve dans une maison !", words: [
      'table', 'chaise', 'réfrigérateur', 'frigo', 'télévision', 'télé', 'canapé', 'lit', 'lampe', 'armoire', 'miroir',
      'fourchette', 'couteau', 'cuillère', 'assiette', 'verre', 'tasse', 'casserole', 'poêle', 'four', 'micro ondes',
      'oreiller', 'couverture', 'tapis', 'rideau', 'horloge', 'téléphone', 'ordinateur', 'balai', 'aspirateur', 'brosse',
      'savon', 'serviette', 'peigne', 'radio', 'ventilateur', 'climatiseur', 'machine à laver', 'fer à repasser', 'bouilloire',
      'cafetière', 'bougie', 'vase', 'cadre', 'étagère', 'commode', 'bureau', 'fauteuil', 'tabouret', 'poubelle', 'clé',
    ]),
  ]),
  Category(id: 'nourriture', label: 'Nourriture', prompts: [
    Prompt(lead: 'Cite des', keyword: 'FRUITS', tail: 'que tu adores !', words: [
      'pomme', 'poire', 'banane', 'orange', 'mangue', 'ananas', 'fraise', 'cerise', 'raisin', 'citron', 'kiwi', 'pastèque',
      'melon', 'papaye', 'goyave', 'avocat', 'noix de coco', 'pêche', 'abricot', 'prune', 'framboise', 'myrtille',
      'mandarine', 'pamplemousse', 'grenade', 'figue', 'litchi', 'fruit de la passion', 'corossol', 'safou',
    ]),
  ]),
  Category(id: 'metiers', label: 'Métiers', prompts: [
    Prompt(lead: 'Cite des', keyword: 'MÉTIERS', tail: 'qui sauvent des vies !', words: [
      'médecin', 'docteur', 'infirmier', 'infirmière', 'pompier', 'policier', 'chirurgien', 'ambulancier', 'secouriste',
      'sage femme', 'pharmacien', 'gendarme', 'militaire', 'soldat', 'maître nageur', 'vétérinaire', 'dentiste', 'pilote',
    ]),
  ]),
  Category(id: 'sports', label: 'Sports', prompts: [
    Prompt(lead: 'Cite des', keyword: 'SPORTS', tail: 'avec un ballon !', words: [
      'football', 'basketball', 'basket', 'handball', 'volleyball', 'volley', 'rugby', 'tennis', 'water polo',
      'football américain', 'baseball', 'golf', 'ping pong', 'tennis de table', 'beach volley', 'futsal', 'cricket', 'bowling',
    ]),
  ]),
  Category(id: 'films', label: 'Films / Séries', prompts: [
    Prompt(lead: 'Cite des', keyword: 'GENRES', tail: 'de films !', words: [
      'comédie', 'action', 'horreur', 'drame', 'science fiction', 'animation', 'dessin animé', 'thriller', 'romance',
      'documentaire', 'western', 'fantastique', 'policier', 'aventure', 'comédie musicale', 'guerre', 'biopic',
    ]),
  ]),
  Category(id: 'musique', label: 'Musique', prompts: [
    Prompt(lead: 'Cite des', keyword: 'INSTRUMENTS', tail: 'de musique !', words: [
      'guitare', 'piano', 'batterie', 'violon', 'flûte', 'trompette', 'saxophone', 'tambour', 'balafon', 'harpe', 'basse',
      'clarinette', 'accordéon', 'violoncelle', 'trombone', 'harmonica', 'xylophone', 'djembé', 'kora', 'synthétiseur',
      'tam tam', 'maracas', 'triangle', 'ukulélé', 'contrebasse', 'orgue', 'cymbale',
    ]),
  ]),
  Category(id: 'vehicules', label: 'Véhicules', prompts: [
    Prompt(lead: 'Cite des', keyword: 'VÉHICULES', tail: 'qui roulent !', words: [
      'voiture', 'moto', 'vélo', 'bus', 'camion', 'train', 'tracteur', 'taxi', 'tramway', 'scooter', 'trottinette',
      'ambulance', 'camionnette', 'quad', 'métro', 'car', 'bicyclette', 'skateboard', 'tank', 'char', 'jeep', '4x4',
    ]),
  ]),
  Category(id: 'autres', label: 'Autres', prompts: [
    Prompt(lead: 'Cite des', keyword: 'COULEURS', tail: '!', words: [
      'rouge', 'bleu', 'vert', 'jaune', 'orange', 'violet', 'rose', 'noir', 'blanc', 'gris', 'marron', 'beige', 'turquoise',
      'or', 'argent', 'bordeaux', 'indigo', 'cyan', 'magenta', 'kaki', 'mauve', 'lilas', 'corail',
    ]),
  ]),
];
