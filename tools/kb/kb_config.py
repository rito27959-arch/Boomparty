"""Configuration des catégories jouables de BOOM PARTY.

Chaque catégorie combine :
- des requêtes Wikidata (CC0) filtrées par popularité (nombre de sitelinks) ;
- des listes d'amorçage écrites à la main (mot canonique + synonymes vraiment
  équivalents dans une partie, ex. réfrigérateur = frigo = frigidaire) ;
- des exclusions.

Les QID des classes sont vérifiés à chaque exécution : le pipeline échoue si le
libellé Wikidata ne correspond pas au libellé attendu (garde-fou contre une
erreur d'identifiant).
"""

# QID → libellé anglais attendu (contrôle d'intégrité)
CLASSES = {
    'Q6256': 'country',
    'Q1065': 'United Nations',
    'Q729': 'animal',
    'Q16521': 'taxon',
    'Q34379': 'musical instrument',
    'Q349': 'sport',
    'Q42889': 'vehicle',
    'Q28640': 'profession',
    'Q11004': 'vegetable',
    'Q212920': 'home appliance',
    'Q14745': 'furniture',
    'Q11460': 'clothing',
    'Q1075': 'color',
    'Q201658': 'film genre',
    'Q188451': 'music genre',
    'Q484170': 'commune of France',
    'Q11344': 'chemical element',
    'Q40050': 'drink',
    'Q746549': 'dish',
    'Q39546': 'physical tool',
    'Q506': 'flower',
    'Q7377': 'mammal',
    'Q5113': 'bird',
    'Q10811': 'reptile',
    'Q10908': 'amphibian',
}

# Exclut les choses individuelles : modèles de produits (fabricant, marque,
# développeur), compétitions et organisations (pays, siège, date), êtres
# vivants nommés (sexe, naissance). On ne garde que des notions génériques.
NOT_INDIVIDUAL = """
  FILTER NOT EXISTS {{ ?item wdt:P176|wdt:P1716|wdt:P178|wdt:P17|wdt:P159|wdt:P569|wdt:P21|wdt:P585|wdt:P580 [] }}"""

# Gabarits SPARQL. {cls} = QID de la classe, {min} = sitelinks minimum.
SUBCLASS = """
SELECT DISTINCT ?item ?sl WHERE {{
  ?item wdt:P279* wd:{cls} .
  ?item wikibase:sitelinks ?sl . FILTER(?sl >= {min})""" + NOT_INDIVIDUAL + """
}}"""

INSTANCE = """
SELECT DISTINCT ?item ?sl WHERE {{
  ?item wdt:P31/wdt:P279* wd:{cls} .
  ?item wikibase:sitelinks ?sl . FILTER(?sl >= {min})""" + NOT_INDIVIDUAL + """
}}"""

INSTANCE_OR_SUBCLASS = """
SELECT DISTINCT ?item ?sl WHERE {{
  {{ ?item wdt:P279* wd:{cls} . }} UNION {{ ?item wdt:P31/wdt:P279* wd:{cls} . }}
  ?item wikibase:sitelinks ?sl . FILTER(?sl >= {min})""" + NOT_INDIVIDUAL + """
}}"""

UN_MEMBERS = """
SELECT DISTINCT ?item ?sl WHERE {
  ?item wdt:P463 wd:Q1065 ; wdt:P31 wd:Q3624078 .
  ?item wikibase:sitelinks ?sl .
}"""

# Capitales actuelles seulement (déclaration P36 sans date de fin, rang non déprécié).
CAPITALS = """
SELECT DISTINCT ?item ?sl WHERE {
  ?country wdt:P463 wd:Q1065 ; wdt:P31 wd:Q3624078 ; p:P36 ?st .
  ?st ps:P36 ?item . FILTER NOT EXISTS { ?st pq:P582 [] }
  FILTER NOT EXISTS { ?st wikibase:rank wikibase:DeprecatedRank }
  ?item wikibase:sitelinks ?sl .
}"""

# Espèces populaires d'un groupe (parcours P171+ depuis la racine du groupe :
# beaucoup moins coûteux que de filtrer tous les taxons de Wikidata).
ANIMAL_GROUP = """
SELECT DISTINCT ?item ?sl WHERE {{
  ?item wdt:P171+ wd:{grp} ; wdt:P105 wd:Q7432 ; wikibase:sitelinks ?sl . FILTER(?sl >= {min})
}}"""
ANIMALS = [ANIMAL_GROUP.format(grp=g, min=m) for g, m in
           (('Q7377', 70), ('Q5113', 80), ('Q10811', 80), ('Q10908', 80))]

FRENCH_CITIES = """
SELECT DISTINCT ?item ?sl WHERE {
  ?item wdt:P31 wd:Q484170 ; wdt:P1082 ?pop . FILTER(?pop >= 40000)
  ?item wikibase:sitelinks ?sl .
}"""

S = lambda *words: list(words)  # noqa: E731

CATEGORIES = [
    {
        'id': 'animaux', 'name': 'Animaux', 'game': 'animaux',
        'prompts': [('Cite des', 'ANIMAUX', 'que tu connais !')],
        'queries': ANIMALS,
        'seeds': [
            S('chien', 'toutou', 'clebs'), S('chat', 'minou', 'matou'), S('vache'), S('cochon', 'porc'), S('poule'),
            S('coq'), S('mouton'), S('chèvre', 'bique'), S('cheval', 'dada'), S('âne', 'baudet'), S('canard'),
            S('oie'), S('dinde'), S('lapin'), S('lion'), S('tigre'), S('éléphant'), S('girafe'), S('zèbre'),
            S('singe'), S('gorille'), S('chimpanzé'), S('ours'), S('loup'), S('renard'), S('crocodile'),
            S('hippopotame'), S('rhinocéros'), S('guépard'), S('panthère'), S('léopard'), S('hyène'),
            S('kangourou'), S('koala'), S('panda'), S('serpent'), S('aigle'), S('cerf'), S('sanglier'),
            S('antilope'), S('gazelle'), S('buffle'), S('jaguar'), S('lynx'), S('chameau'), S('dromadaire'),
            S('autruche'), S('souris'), S('rat'), S('hamster'), S('écureuil'), S('hérisson'), S('taupe'),
            S('requin'), S('baleine'), S('dauphin'), S('phoque'), S('pingouin', 'manchot'), S('pieuvre', 'poulpe'),
            S('crabe'), S('homard'), S('crevette'), S('tortue'), S('grenouille'), S('crapaud'), S('lézard'),
            S('papillon'), S('abeille'), S('fourmi'), S('mouche'), S('moustique'), S('araignée'), S('scorpion'),
            S('escargot'), S('ver de terre', 'lombric'), S('pigeon'), S('corbeau'), S('perroquet'), S('hibou'),
            S('chouette'), S('moineau'), S('mouette', 'goéland'), S('flamant rose', 'flamant'), S('paon'),
            S('cygne'), S('chauve-souris'), S('castor'), S('loutre'), S('blaireau'), S('morse'), S('lama'),
            S('alpaga'), S('bison'), S('yack', 'yak'), S('élan'), S('renne', 'caribou'), S('okapi'),
            S('pangolin'), S('gnou'), S('phacochère'), S('caméléon'), S('iguane'), S('salamandre'),
            S('méduse'), S('étoile de mer'), S('hippocampe'), S('anguille'), S('saumon'), S('thon'),
            S('sardine'), S('carpe'), S('truite'), S('poisson rouge'), S('mille-pattes'), S('coccinelle'),
            S('libellule'), S('sauterelle'), S('criquet'), S('grillon'), S('cafard', 'blatte'), S('guêpe'),
            S('frelon'), S('chenille'), S('puce'), S('pou'), S('tique'), S('poussin'), S('veau'), S('agneau'),
            S('taureau'), S('bœuf'), S('jument'), S('poney'), S('mulet'), S('pintade'), S('dindon'),
        ],
    },
    {
        'id': 'animaux_ferme', 'name': 'Animaux de la ferme', 'game': 'animaux',
        'prompts': [('Cite des', 'ANIMAUX', 'de la ferme !')],
        'queries': [],
        'seeds': [
            S('vache'), S('taureau'), S('bœuf'), S('veau'), S('cochon', 'porc'), S('truie'), S('porcelet'),
            S('poule'), S('coq'), S('poussin'), S('canard'), S('oie'), S('dinde'), S('dindon'), S('pintade'),
            S('mouton'), S('brebis'), S('bélier'), S('agneau'), S('chèvre', 'bique'), S('bouc'), S('chevreau'),
            S('cheval'), S('jument'), S('poulain'), S('poney'), S('âne', 'baudet'), S('mulet'), S('lapin'),
            S('chien'), S('chat'), S('souris'), S('rat'), S('pigeon'), S('caille'), S('lama'), S('alpaga'),
            S('abeille'), S('buffle'),
        ],
    },
    {
        'id': 'pays', 'name': 'Pays', 'game': 'pays',
        'prompts': [('Cite des', 'PAYS', 'du monde !')],
        'queries': [UN_MEMBERS],
        'seeds': [
            S('États-Unis', 'USA', 'Amérique', 'États-Unis d\'Amérique'), S('Royaume-Uni', 'Angleterre', 'Grande-Bretagne'),
            S('Côte d\'Ivoire'), S('République démocratique du Congo', 'RDC', 'Congo-Kinshasa'),
            S('République du Congo', 'Congo-Brazzaville'), S('Cameroun'), S('Pays-Bas', 'Hollande'),
            S('Corée du Sud'), S('Corée du Nord'), S('Centrafrique', 'République centrafricaine'),
            S('Tchéquie', 'République tchèque'), S('Afrique du Sud'),
        ],
    },
    {
        'id': 'capitales', 'name': 'Capitales', 'game': 'pays',
        'prompts': [('Cite des', 'CAPITALES', 'du monde !')],
        'queries': [CAPITALS],
        'seeds': [S('Paris'), S('Yaoundé'), S('Dakar'), S('Abidjan'), S('Libreville'), S('Kinshasa')],
    },
    {
        'id': 'objets_maison', 'name': 'Objets de la maison', 'game': 'objets',
        'prompts': [('Cite des', 'OBJETS', "qu'on trouve dans une maison !")],
        'queries': [SUBCLASS.format(cls='Q212920', min=20), SUBCLASS.format(cls='Q14745', min=20)],
        'seeds': [
            S('table'), S('chaise'), S('réfrigérateur', 'frigo', 'frigidaire', 'réfrigérateur domestique'),
            S('télévision', 'téléviseur', 'télé', 'TV'), S('canapé', 'sofa', 'divan'), S('lit'), S('lampe'),
            S('armoire'), S('miroir', 'glace'), S('fourchette'), S('couteau'), S('cuillère', 'cuiller'),
            S('assiette'), S('verre'), S('tasse'), S('casserole'), S('poêle'), S('four'),
            S('four à micro-ondes', 'micro-ondes', 'micro-onde'), S('oreiller'), S('couverture'), S('tapis'),
            S('rideau'), S('horloge', 'pendule'), S('téléphone', 'portable', 'smartphone'),
            S('ordinateur', 'PC', 'ordi'), S('ordinateur portable', 'laptop'), S('balai'), S('aspirateur'),
            S('brosse'), S('brosse à dents'), S('savon'), S('serviette'), S('peigne'), S('radio'),
            S('ventilateur'), S('climatiseur', 'clim', 'climatisation'), S('machine à laver', 'lave-linge'),
            S('lave-vaisselle'), S('fer à repasser'), S('bouilloire'), S('cafetière'), S('bougie'), S('vase'),
            S('cadre'), S('étagère'), S('commode'), S('bureau'), S('fauteuil'), S('tabouret'),
            S('poubelle'), S('clé', 'clef'), S('télécommande', 'zapette'), S('matelas'), S('drap'),
            S('robinet'), S('évier'), S('baignoire'), S('douche'), S('toilettes', 'WC', 'cabinets'),
            S('lavabo'), S('ampoule'), S('interrupteur'), S('prise électrique', 'prise'), S('ciseaux'),
            S('stylo'), S('livre'), S('cuisinière', 'gazinière'), S('grille-pain'), S('mixeur', 'blender'),
            S('table à manger', 'table de salle à manger'), S('table de chevet'), S('porte-manteau'),
            S('parapluie'), S('cintre'), S('seau'), S('serpillière'), S('éponge'), S('coussin'),
            S('réveil'), S('congélateur'), S('hotte'), S('radiateur'), S('chauffe-eau'), S('boîte aux lettres'),
        ],
    },
    {
        'id': 'objets_cuisine', 'name': 'Objets de la cuisine', 'game': 'objets',
        'prompts': [('Cite des', 'OBJETS', "qu'on trouve dans une cuisine !")],
        'queries': [],
        'seeds': [
            S('casserole'), S('poêle'), S('marmite', 'faitout'), S('cocotte', 'cocotte-minute', 'autocuiseur'),
            S('fourchette'), S('couteau'), S('cuillère', 'cuiller'), S('louche'), S('spatule'), S('fouet'),
            S('assiette'), S('bol'), S('verre'), S('tasse'), S('mug'), S('saladier'), S('passoire'),
            S('râpe'), S('économe', 'éplucheur'), S('ouvre-boîte'), S('tire-bouchon'), S('planche à découper'),
            S('rouleau à pâtisserie'), S('moule'), S('plateau'), S('carafe'), S('théière'), S('cafetière'),
            S('bouilloire'), S('grille-pain'), S('mixeur', 'blender'), S('robot'), S('balance'),
            S('réfrigérateur', 'frigo', 'frigidaire'), S('congélateur'), S('four'), S('four à micro-ondes', 'micro-ondes'),
            S('cuisinière', 'gazinière'), S('plaque de cuisson'), S('hotte'), S('lave-vaisselle'), S('évier'),
            S('robinet'), S('éponge'), S('torchon'), S('tablier'), S('poubelle'), S('gant de cuisine', 'manique'),
            S('sel'), S('poivrier'), S('salière'), S('huile'), S('papier aluminium', 'papier alu'),
            S('film plastique', 'film alimentaire'), S('boîte de conservation', 'tupperware'), S('pilon'),
            S('mortier'), S('égouttoir'), S('ciseaux'), S('entonnoir'), S('pinceau'), S('cuit-vapeur'),
            S('friteuse'), S('gaufrier'), S('pichet'), S('bouteille'), S('table'), S('chaise'),
        ],
    },
    {
        'id': 'fruits', 'name': 'Fruits', 'game': 'nourriture',
        'prompts': [('Cite des', 'FRUITS', 'que tu adores !')],
        'queries': [],
        'seeds': [
            S('pomme'), S('poire'), S('banane'), S('orange'), S('mangue'), S('ananas'), S('fraise'), S('cerise'),
            S('raisin'), S('citron'), S('citron vert'), S('kiwi'), S('pastèque', 'melon d\'eau'), S('melon'),
            S('papaye'), S('goyave'), S('avocat'), S('noix de coco', 'coco'), S('pêche'), S('abricot'),
            S('prune'), S('framboise'), S('myrtille'), S('mandarine'), S('clémentine'), S('pamplemousse'),
            S('grenade'), S('figue'), S('litchi', 'letchi'), S('fruit de la passion', 'maracuja'), S('corossol'),
            S('safou', 'prune africaine'), S('mûre'), S('groseille'), S('cassis'), S('nectarine'), S('datte'),
            S('kaki'), S('banane plantain', 'plantain'), S('carambole'), S('ramboutan'), S('fruit du dragon', 'pitaya'),
            S('goyave'), S('tamarin'), S('jacquier'), S('coing'), S('olive'), S('tomate'), S('canneberge', 'cranberry'),
        ],
    },
    {
        'id': 'legumes', 'name': 'Légumes', 'game': 'nourriture',
        'prompts': [('Cite des', 'LÉGUMES', 'du potager !')],
        'queries': [INSTANCE_OR_SUBCLASS.format(cls='Q11004', min=40)],
        'seeds': [
            S('carotte'), S('pomme de terre', 'patate'), S('tomate'), S('salade', 'laitue'), S('chou'),
            S('chou-fleur'), S('brocoli'), S('haricot vert', 'haricot'), S('petit pois'), S('poireau'),
            S('oignon'), S('ail'), S('courgette'), S('aubergine'), S('poivron'), S('concombre'), S('épinard'),
            S('navet'), S('radis'), S('betterave'), S('céleri'), S('citrouille', 'potiron'), S('courge'),
            S('maïs'), S('champignon'), S('patate douce'), S('manioc'), S('igname'), S('gombo'),
            S('asperge'), S('artichaut'), S('endive'), S('fenouil'), S('échalote'), S('piment'),
            S('lentille'), S('pois chiche'), S('macabo', 'taro'), S('ndolé'),
        ],
    },
    {
        'id': 'plats', 'name': 'Plats', 'game': 'nourriture',
        'prompts': [('Cite des', 'PLATS', 'délicieux !')],
        'queries': [INSTANCE_OR_SUBCLASS.format(cls='Q746549', min=45)],
        'seeds': [
            S('pizza'), S('hamburger', 'burger'), S('frites'), S('spaghetti', 'spaghettis'), S('lasagnes', 'lasagne'),
            S('couscous'), S('paella'), S('sushi', 'sushis'), S('ndolé'), S('poulet DG'), S('eru'), S('koki'),
            S('thiéboudienne', 'riz au poisson'), S('mafé'), S('yassa'), S('attiéké'), S('alloco'), S('foutou'),
            S('fufu', 'foufou'), S('tajine'), S('ratatouille'), S('quiche'), S('crêpe'), S('omelette'),
            S('soupe'), S('salade'), S('sandwich'), S('kebab'), S('tacos'), S('poulet rôti'), S('steak'),
            S('riz cantonais'), S('pot-au-feu'), S('bœuf bourguignon'), S('croque-monsieur'), S('raclette'),
            S('fondue'), S('gâteau'), S('tarte'), S('beignet', 'beignets'), S('brochette', 'brochettes', 'soya'),
        ],
    },
    {
        'id': 'boissons', 'name': 'Boissons', 'game': 'nourriture',
        'prompts': [('Cite des', 'BOISSONS', 'rafraîchissantes !')],
        'queries': [],
        'seeds': [
            S('eau'), S('jus d\'orange'), S('jus de pomme'), S('jus d\'ananas'), S('limonade'), S('soda'),
            S('coca', 'coca-cola', 'cola'), S('thé'), S('café'), S('chocolat chaud'), S('lait'), S('smoothie'),
            S('milkshake'), S('bissap', 'jus d\'hibiscus'), S('jus de gingembre', 'gingembre'),
            S('sirop'), S('eau gazeuse'), S('thé glacé'), S('jus de citron', 'citronnade'), S('jus de mangue'),
            S('jus de goyave'), S('yaourt à boire'), S('tisane', 'infusion'), S('lait de coco'), S('grenadine'),
        ],
    },
    {
        'id': 'metiers', 'name': 'Métiers', 'game': 'metiers',
        'prompts': [('Cite des', 'MÉTIERS', 'que tu connais !')],
        'queries': [INSTANCE_OR_SUBCLASS.format(cls='Q28640', min=35)],
        'seeds': [
            S('médecin', 'docteur'), S('infirmier', 'infirmière'), S('pompier'), S('policier', 'policière', 'flic'),
            S('chirurgien', 'chirurgienne'), S('ambulancier', 'ambulancière'), S('sage-femme'),
            S('pharmacien', 'pharmacienne'), S('gendarme'), S('militaire', 'soldat'), S('vétérinaire', 'véto'),
            S('dentiste'), S('pilote'), S('professeur', 'prof', 'enseignant', 'enseignante'), S('instituteur', 'institutrice', 'maître d\'école'),
            S('boulanger', 'boulangère'), S('boucher', 'bouchère'), S('cuisinier', 'cuisinière', 'chef cuisinier'),
            S('coiffeur', 'coiffeuse'), S('avocat', 'avocate'), S('juge'), S('architecte'), S('ingénieur', 'ingénieure'),
            S('mécanicien', 'mécanicienne', 'mécano'), S('électricien', 'électricienne'), S('plombier', 'plombière'),
            S('menuisier', 'menuisière'), S('maçon'), S('peintre'), S('agriculteur', 'agricultrice', 'paysan', 'fermier', 'fermière'),
            S('chauffeur', 'chauffeuse', 'conducteur'), S('taxi', 'chauffeur de taxi'), S('facteur', 'factrice'),
            S('vendeur', 'vendeuse'), S('commerçant', 'commerçante'), S('caissier', 'caissière'), S('serveur', 'serveuse'),
            S('journaliste'), S('photographe'), S('chanteur', 'chanteuse'), S('acteur', 'actrice', 'comédien', 'comédienne'),
            S('musicien', 'musicienne'), S('danseur', 'danseuse'), S('footballeur', 'footballeuse'), S('astronaute'),
            S('informaticien', 'informaticienne', 'développeur', 'programmeur'), S('comptable'), S('banquier', 'banquière'),
            S('secrétaire'), S('couturier', 'couturière', 'tailleur'), S('pêcheur', 'pêcheuse'), S('jardinier', 'jardinière'),
            S('éboueur'), S('gardien', 'gardienne', 'vigile'), S('styliste'), S('écrivain', 'écrivaine', 'auteur'),
        ],
    },
    {
        'id': 'sports', 'name': 'Sports', 'game': 'sports',
        'prompts': [('Cite des', 'SPORTS', 'que tu connais !')],
        'queries': [INSTANCE_OR_SUBCLASS.format(cls='Q349', min=40)],
        'seeds': [
            S('football', 'foot', 'soccer'), S('basketball', 'basket', 'basket-ball'), S('handball', 'hand'),
            S('volleyball', 'volley', 'volley-ball'), S('rugby'), S('tennis'), S('tennis de table', 'ping-pong'),
            S('natation'), S('athlétisme'), S('boxe'), S('judo'), S('karaté'), S('lutte'), S('cyclisme', 'vélo'),
            S('golf'), S('ski'), S('patinage'), S('gymnastique', 'gym'), S('escrime'), S('équitation'),
            S('aviron'), S('canoë', 'kayak'), S('surf'), S('skateboard', 'skate'), S('escalade'), S('badminton'),
            S('baseball'), S('cricket'), S('hockey'), S('water-polo'), S('marathon'), S('course à pied', 'running'),
            S('taekwondo'), S('haltérophilie'), S('triathlon'), S('plongée'), S('pétanque', 'boules'),
            S('formule 1', 'F1'), S('beach-volley'), S('futsal'),
        ],
    },
    {
        'id': 'vehicules', 'name': 'Véhicules', 'game': 'vehicules',
        'prompts': [('Cite des', 'VÉHICULES', 'qui roulent, volent ou naviguent !')],
        'queries': [SUBCLASS.format(cls='Q42889', min=40)],
        'seeds': [
            S('voiture', 'auto', 'automobile', 'bagnole'), S('moto', 'motocyclette'), S('vélo', 'bicyclette', 'bécane'),
            S('bus', 'autobus'), S('car', 'autocar'), S('camion', 'poids lourd'), S('train'), S('tramway', 'tram'),
            S('métro'), S('tracteur'), S('taxi'), S('scooter'), S('trottinette'), S('ambulance'), S('camionnette'),
            S('quad'), S('avion'), S('hélicoptère'), S('bateau'), S('navire'), S('paquebot'), S('pirogue'),
            S('sous-marin'), S('fusée'), S('montgolfière'), S('jeep', '4x4'), S('char', 'tank'), S('calèche'),
            S('benne', 'camion-benne'), S('bulldozer'), S('pelleteuse'), S('moto-taxi', 'bendskin'),
            S('planeur'), S('jet-ski'), S('voilier'), S('canot'), S('kayak'), S('limousine'), S('minibus'),
            S('skateboard', 'skate'), S('patins à roulettes', 'rollers'), S('dépanneuse'), S('camion de pompiers'),
        ],
    },
    {
        'id': 'instruments', 'name': 'Instruments de musique', 'game': 'musique',
        'prompts': [('Cite des', 'INSTRUMENTS', 'de musique !')],
        'queries': [SUBCLASS.format(cls='Q34379', min=30)],
        'seeds': [
            S('guitare'), S('guitare électrique'), S('piano'), S('batterie'), S('violon'), S('flûte'),
            S('trompette'), S('saxophone', 'saxo'), S('tambour'), S('balafon'), S('harpe'), S('guitare basse', 'basse'),
            S('clarinette'), S('accordéon'), S('violoncelle'), S('trombone'), S('harmonica'), S('xylophone'),
            S('djembé'), S('kora'), S('synthétiseur', 'synthé'), S('tam-tam'), S('maracas'), S('triangle'),
            S('ukulélé'), S('contrebasse'), S('orgue'), S('cymbale'), S('tambourin'), S('banjo'), S('hautbois'),
            S('cor'), S('tuba'), S('mandoline'), S('castagnettes'), S('flûte à bec'), S('cornemuse'), S('sanza'),
        ],
    },
    {
        'id': 'vetements', 'name': 'Vêtements', 'game': 'autres',
        'prompts': [('Cite des', 'VÊTEMENTS', 'de ta garde-robe !')],
        'queries': [SUBCLASS.format(cls='Q11460', min=30)],
        'seeds': [
            S('pantalon'), S('jean', 'jeans'), S('chemise'), S('tee-shirt', 't-shirt'), S('pull', 'pull-over', 'chandail'),
            S('veste'), S('manteau'), S('robe'), S('jupe'), S('short'), S('chaussette', 'chaussettes'),
            S('chaussure', 'chaussures'), S('basket', 'baskets'), S('sandale', 'sandales'), S('casquette'),
            S('chapeau'), S('bonnet'), S('écharpe'), S('gant', 'gants'), S('cravate'), S('ceinture'),
            S('pyjama'), S('maillot de bain'), S('boubou'), S('pagne'), S('kaba'), S('blouson'), S('costume'),
            S('slip', 'culotte'), S('soutien-gorge'), S('survêtement', 'jogging'), S('sweat', 'sweat-shirt'),
            S('débardeur'), S('imperméable', 'ciré'), S('bottes'), S('tongs'), S('foulard'), S('gilet'),
        ],
    },
    {
        'id': 'couleurs', 'name': 'Couleurs', 'game': 'autres',
        'prompts': [('Cite des', 'COULEURS', '!')],
        'queries': [],
        'seeds': [
            S('rouge'), S('bleu'), S('vert'), S('jaune'), S('orange'), S('violet', 'mauve'), S('rose'), S('noir'),
            S('blanc'), S('gris'), S('marron', 'brun'), S('beige'), S('turquoise'), S('doré', 'or'),
            S('argenté', 'argent'), S('bordeaux'), S('indigo'), S('cyan'), S('magenta'), S('kaki'), S('lilas'),
            S('corail'), S('bleu marine', 'marine'), S('bleu ciel'), S('vert pomme'), S('saumon'), S('ocre'),
            S('fuchsia'), S('crème'), S('écarlate'), S('pourpre'), S('lavande'), S('émeraude'), S('ivoire'),
        ],
    },
    {
        'id': 'corps', 'name': 'Parties du corps', 'game': 'autres',
        'prompts': [('Cite des', 'PARTIES DU CORPS', '!')],
        'queries': [],
        'seeds': [
            S('tête'), S('cheveu', 'cheveux'), S('œil', 'yeux'), S('oreille'), S('nez'), S('bouche'),
            S('dent'), S('langue'), S('lèvre'), S('joue'), S('menton'), S('front'), S('sourcil'), S('cou'),
            S('épaule'), S('bras'), S('coude'), S('poignet'), S('main'), S('doigt'), S('pouce'), S('ongle'),
            S('poitrine'), S('ventre'), S('nombril'), S('dos'), S('hanche'), S('fesse'), S('jambe'),
            S('genou'), S('cheville'), S('pied'), S('orteil'), S('talon'), S('cœur'), S('poumon'), S('foie'),
            S('estomac'), S('cerveau'), S('rein'), S('peau'), S('os'), S('muscle'), S('cil'), S('mollet'),
            S('cuisse'), S('gorge'), S('nuque'), S('paupière'),
        ],
    },
    {
        'id': 'genres_films', 'name': 'Genres de films', 'game': 'films',
        'prompts': [('Cite des', 'GENRES', 'de films !')],
        'queries': [INSTANCE.format(cls='Q201658', min=40)],
        'seeds': [
            S('comédie'), S('action', 'film d\'action'), S('horreur', 'film d\'horreur'), S('drame'),
            S('science-fiction', 'SF'), S('animation', 'dessin animé', 'film d\'animation'), S('thriller'),
            S('romance', 'film romantique', 'comédie romantique'), S('documentaire'), S('western'),
            S('fantastique'), S('policier', 'film policier'), S('aventure', 'film d\'aventure'),
            S('comédie musicale'), S('film de guerre', 'guerre'), S('biopic', 'film biographique'),
            S('film de super-héros', 'super-héros'), S('film d\'espionnage', 'espionnage'), S('fantasy'),
            S('film catastrophe'), S('film historique', 'historique'),
        ],
    },
    {
        'id': 'genres_musique', 'name': 'Styles de musique', 'game': 'musique',
        'prompts': [('Cite des', 'STYLES', 'de musique !')],
        'queries': [INSTANCE.format(cls='Q188451', min=60)],
        'seeds': [
            S('rap', 'hip-hop', 'hip hop'), S('rock'), S('pop'), S('jazz'), S('reggae'), S('blues'), S('soul'),
            S('funk'), S('disco'), S('techno'), S('house'), S('électro', 'musique électronique'), S('classique', 'musique classique'),
            S('makossa'), S('bikutsi'), S('afrobeat', 'afrobeats'), S('coupé-décalé'), S('zouk'), S('salsa'),
            S('rumba', 'rumba congolaise'), S('ndombolo'), S('gospel'), S('R&B', 'RnB'), S('métal', 'heavy metal'),
            S('punk'), S('country'), S('kompa', 'konpa'), S('dancehall'), S('slam'), S('opéra'), S('bossa nova'),
            S('raï'), S('amapiano'), S('trap'),
        ],
    },
    {
        'id': 'villes_france', 'name': 'Villes de France', 'game': 'pays',
        'prompts': [('Cite des', 'VILLES', 'de France !')],
        'queries': [FRENCH_CITIES],
        'seeds': [S('Paris'), S('Marseille'), S('Lyon'), S('Toulouse'), S('Nice'), S('Nantes'), S('Bordeaux'), S('Lille')],
    },
    {
        'id': 'elements', 'name': 'Éléments chimiques', 'game': 'autres',
        'prompts': [('Cite des', 'ÉLÉMENTS', 'chimiques !')],
        'queries': [INSTANCE.format(cls='Q11344', min=0)],
        'seeds': [],
    },
]

# Défis à plusieurs réponses (règle distincte des catégories simples)
CHALLENGES = [
    {'id': 'pays_m', 'category': 'pays', 'count': 3, 'first_letter': 'm', 'prompt': ('Cite', 'TROIS PAYS', 'commençant par M !')},
    {'id': 'pays_b', 'category': 'pays', 'count': 3, 'first_letter': 'b', 'prompt': ('Cite', 'TROIS PAYS', 'commençant par B !')},
    {'id': 'animaux_c', 'category': 'animaux', 'count': 3, 'first_letter': 'c', 'prompt': ('Cite', 'TROIS ANIMAUX', 'commençant par C !')},
    {'id': 'fruits_p', 'category': 'fruits', 'count': 2, 'first_letter': 'p', 'prompt': ('Cite', 'DEUX FRUITS', 'commençant par P !')},
    {'id': 'metiers_p', 'category': 'metiers', 'count': 3, 'first_letter': 'p', 'prompt': ('Cite', 'TROIS MÉTIERS', 'commençant par P !')},
    {'id': 'sports_b', 'category': 'sports', 'count': 2, 'first_letter': 'b', 'prompt': ('Cite', 'DEUX SPORTS', 'commençant par B !')},
]
