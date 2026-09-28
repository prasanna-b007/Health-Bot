"""Non-medication care plans for each condition in dataset.csv.

The precaution CSV gives four terse fragments per disease ("stop irritation",
"avoid oily food") with no sense of what to do first, what makes things worse,
or when self-care has stopped being the right answer. This module carries the
long form: what to do, what to avoid, and the red flags that mean stop managing
this at home and get seen.

Nothing here names a drug, a dose or a brand. Everything is rest, fluids, diet,
hygiene, positioning, environment, activity and monitoring -- the things a
person can act on themselves. Anything pharmacological is deliberately left to
the clinician the disposition already points them at.

Keys are canonical disease names (see normalize.normalize_disease), matching
specialists.SPECIALISTS.
"""
from typing import Dict, List, Optional

from .normalize import normalize_disease

# Used when a condition has no authored plan. Safe for anything: it assumes
# nothing about the illness beyond the fact that the user has one.
DEFAULT_CARE_PLAN: Dict[str, object] = {
    "goal": "Support your recovery and notice early if this is getting worse.",
    "do": [
        "Rest and give your body room to recover",
        "Drink fluids steadily through the day",
        "Eat light, regular meals even if your appetite is low",
        "Write down your symptoms and when they change",
    ],
    "avoid": [
        "Pushing through strenuous activity",
        "Alcohol and smoking while you recover",
        "Waiting it out if you are getting steadily worse",
    ],
    "red_flags": [
        "Difficulty breathing or chest pain",
        "Confusion, fainting or a very severe headache",
        "A high fever that will not come down",
        "Symptoms that keep worsening over several days",
    ],
}

CARE_PLANS: Dict[str, Dict[str, object]] = {
    "(vertigo) paroymsal positional vertigo": {
        "goal": "Reduce the spinning episodes and avoid injuring yourself during one.",
        "do": [
            "Sit or lie down the moment the spinning starts, and stay still until it passes",
            "Get out of bed in stages: sit on the edge first, then stand slowly",
            "Sleep with your head slightly raised on an extra pillow",
            "Keep floors clear and a light on at night to lower your fall risk",
            "Ask your doctor about repositioning manoeuvres, which often resolve this quickly",
        ],
        "avoid": [
            "Sudden head turns, or tipping your head far back or down",
            "Driving, ladders or swimming until the episodes have settled",
            "Lying on the side that reliably triggers an attack",
        ],
        "red_flags": [
            "Vertigo with weakness, numbness or slurred speech",
            "Double vision or trouble walking in a straight line",
            "New hearing loss on one side",
            "A severe headache alongside the dizziness",
        ],
    },
    "acne": {
        "goal": "Calm the skin and stop new breakouts without scarring it.",
        "do": [
            "Wash the area twice daily with lukewarm water and a mild, non-soap cleanser",
            "Pat dry gently rather than scrubbing",
            "Choose skincare and makeup labelled non-comedogenic or oil-free",
            "Change pillowcases and face towels often",
            "Keep hair, phone screens and hands off your face",
        ],
        "avoid": [
            "Picking, squeezing or popping spots -- this is what leaves scars",
            "Harsh scrubs, astringents and over-washing, which inflame the skin further",
            "Heavy oil-based cosmetics and sleeping in makeup",
        ],
        "red_flags": [
            "Deep, painful lumps or cysts under the skin",
            "Acne that is scarring or spreading quickly",
            "Sudden severe acne with other new changes such as irregular periods or hair growth",
            "Signs of infection: spreading redness, warmth and fever",
        ],
    },
    "aids": {
        "goal": "Stay in specialist care and protect your immune system day to day.",
        "do": [
            "Keep every appointment with your HIV clinic -- consistent specialist care is what changes outcomes here",
            "Eat well-cooked, freshly prepared food and drink safe water",
            "Wash hands thoroughly and often, especially before eating",
            "Keep up to date with the vaccinations your care team recommends",
            "Tell your team about any new symptom early, however minor it seems",
        ],
        "avoid": [
            "Raw or undercooked eggs, meat and shellfish, and unpasteurised dairy",
            "Close contact with people who have chickenpox, measles or active TB",
            "Handling animal litter or soil without gloves",
            "Smoking and alcohol, which add to the strain on your immune system",
        ],
        "red_flags": [
            "Fever lasting more than a few days",
            "Breathlessness or a persistent cough",
            "Unexplained weight loss or night sweats",
            "New confusion, severe headache, vision changes or seizures",
            "White patches in the mouth or pain on swallowing",
        ],
    },
    "alcoholic hepatitis": {
        "goal": "Take the strain off your liver and let it recover what it can.",
        "do": [
            "Stop drinking alcohol completely -- this is the single change that most affects recovery",
            "Ask your doctor about supervised withdrawal before you stop, if you drink heavily",
            "Eat regular, protein-containing meals; undernutrition is common and makes this worse",
            "Rest, and weigh yourself regularly to spot fluid building up",
            "Check with your doctor before taking any over-the-counter remedy or supplement",
        ],
        "avoid": [
            "All alcohol, including small amounts",
            "Salty food, which worsens fluid retention",
            "Herbal or bodybuilding supplements, which can be hard on the liver",
        ],
        "red_flags": [
            "Yellowing of the eyes or skin that is deepening",
            "Vomiting blood, or black tarry stools",
            "A swollen, painful abdomen or rapidly swelling legs",
            "Confusion, drowsiness or disturbed sleep patterns",
            "Fever with shivering",
        ],
    },
    "allergy": {
        "goal": "Settle the current reaction and work out what set it off.",
        "do": [
            "Get away from whatever you think triggered it",
            "Apply a cool compress to itchy or raised skin",
            "Keep a diary of foods, places and products against your symptoms to find the pattern",
            "Rinse skin, hair or eyes that came into contact with the trigger",
            "Shower and change after being outdoors if pollen is your trigger",
        ],
        "avoid": [
            "Scratching, which breaks the skin and invites infection",
            "Hot showers and baths while the skin is flaring",
            "Retrying a suspected food or product to test it, unless a doctor supervises",
        ],
        "red_flags": [
            "Swelling of the lips, tongue or throat",
            "Difficulty breathing, wheezing or a tight chest",
            "Dizziness, fainting or a racing pulse",
            "Widespread hives with vomiting or stomach cramps",
            "These signs are an emergency -- call for help immediately",
        ],
    },
    "arthritis": {
        "goal": "Keep the joints moving and manage pain without making flares worse.",
        "do": [
            "Keep moving with low-impact activity: walking, cycling or swimming",
            "Apply warmth to stiff joints and cold to swollen, hot ones",
            "Work towards a healthy weight -- every kilo lost eases the load on knees and hips",
            "Use supportive shoes, and grab rails or jar openers where they help",
            "Balance activity with rest across the day rather than doing everything at once",
        ],
        "avoid": [
            "Complete rest for days at a time, which stiffens joints further",
            "High-impact exercise during an active flare",
            "Repetitive gripping or kneeling if those joints are the problem",
        ],
        "red_flags": [
            "A single joint that is hot, very swollen and intensely painful",
            "Joint pain with fever or feeling generally unwell",
            "Sudden inability to use or bear weight on a joint",
            "Pain that wakes you every night or is steadily worsening",
        ],
    },
    "bronchial asthma": {
        "goal": "Keep your airways calm and recognise an attack early.",
        "do": [
            "Learn and follow a written asthma action plan agreed with your doctor",
            "Identify and reduce your triggers: dust, smoke, pets, cold air, strong scents",
            "Wash bedding hot and weekly, and keep the bedroom dust-free",
            "Sit upright and breathe slowly and steadily if you feel tight",
            "Warm up gradually before exercise",
        ],
        "avoid": [
            "Smoking, and any room where people are smoking",
            "Known triggers during high pollen or high pollution days",
            "Skipping your prescribed preventer treatment once you feel better",
        ],
        "red_flags": [
            "Too breathless to speak a full sentence, eat or sleep",
            "Reliever treatment not helping, or needed more often than usual",
            "Lips or fingertips turning blue or grey",
            "Chest so tight it feels like you cannot draw breath",
            "These are emergency signs -- get help immediately",
        ],
    },
    "cervical spondylosis": {
        "goal": "Take pressure off the neck and stop the stiffness from setting in.",
        "do": [
            "Set your screen at eye level and sit back in the chair with your shoulders relaxed",
            "Take a movement break every 30-45 minutes",
            "Do gentle neck range-of-motion stretches daily, within a comfortable range",
            "Sleep with a single supportive pillow that keeps your neck level with your spine",
            "Apply warmth to loosen stiff muscles before stretching",
        ],
        "avoid": [
            "Long stretches looking down at a phone or laptop",
            "Carrying heavy bags on one shoulder",
            "Forceful neck cracking or aggressive stretching",
            "Sleeping on your stomach, which twists the neck all night",
        ],
        "red_flags": [
            "Weakness or numbness in an arm or hand that is worsening",
            "Clumsiness, dropping things, or unsteadiness when walking",
            "Loss of bladder or bowel control",
            "Neck pain after a fall or accident",
            "Neck pain with fever or unexplained weight loss",
        ],
    },
    "chicken pox": {
        "goal": "Ease the itch, prevent infected spots, and keep it from spreading.",
        "do": [
            "Stay home until every blister has crusted over",
            "Keep fingernails short and clean; cotton mittens help children at night",
            "Take cool baths and pat dry -- do not rub",
            "Wear loose cotton clothing",
            "Drink plenty of fluids, and offer cold soft foods if the mouth is sore",
        ],
        "avoid": [
            "Scratching the spots, which causes scarring and infection",
            "Contact with pregnant people, newborns and anyone with a weak immune system",
            "Aspirin in children and teenagers -- ask a pharmacist or doctor what is safe instead",
            "Hot baths and harsh soaps, which worsen the itch",
        ],
        "red_flags": [
            "Spots that turn hot, red, swollen or start weeping pus",
            "Fever that returns after first settling",
            "Breathlessness or a persistent cough",
            "Severe headache, neck stiffness, drowsiness or confusion",
            "Not drinking, or no wet nappies in a young child",
        ],
    },
    "chronic cholestasis": {
        "goal": "Manage the itch and keep your liver under regular review.",
        "do": [
            "Keep skin cool -- lukewarm baths, light cotton clothing, a cool bedroom",
            "Moisturise generously after washing while skin is still damp",
            "Eat a low-fat diet with smaller, more frequent meals",
            "Attend your liver follow-up appointments and blood tests",
            "Ask your doctor about fat-soluble vitamin levels, which often run low here",
        ],
        "avoid": [
            "Alcohol entirely",
            "Hot showers and baths, which make the itching far worse",
            "Scratching -- keep nails short and use cool compresses instead",
            "Any new supplement or remedy without checking with your doctor first",
        ],
        "red_flags": [
            "Deepening yellowing of the eyes or skin",
            "Pale stools with dark urine",
            "Fever with shivering and upper abdominal pain",
            "Confusion or unusual drowsiness",
            "Easy bruising or bleeding",
        ],
    },
    "common cold": {
        "goal": "Stay comfortable while it runs its course, and avoid passing it on.",
        "do": [
            "Rest and drink warm fluids regularly",
            "Inhale steam or use a saline rinse to clear a blocked nose",
            "Gargle warm salt water for a sore throat",
            "Sleep with your head slightly raised",
            "Wash hands often and bin used tissues straight away",
        ],
        "avoid": [
            "Expecting antibiotics to help -- colds are viral and do not respond to them",
            "Smoking and smoky rooms, which prolong the cough",
            "Going back to full activity before the fatigue lifts",
        ],
        "red_flags": [
            "Symptoms lasting beyond 10 days without improving",
            "Fever above 38.5C lasting more than three days, or returning after settling",
            "Breathlessness, wheezing or chest pain",
            "Severe sinus or ear pain, or a stiff neck",
            "Coughing up blood",
        ],
    },
    "dengue": {
        "goal": "Stay hydrated and catch the danger window, which is when the fever drops.",
        "do": [
            "Drink far more fluid than usual: water, oral rehydration solution, soups, juices",
            "Rest completely -- this illness is more draining than it first appears",
            "Watch your temperature and how much you are passing urine",
            "Ask your doctor which pain or fever relief is safe for you",
            "Use nets and repellent so mosquitoes do not carry it onward from you",
        ],
        "avoid": [
            "Aspirin and anti-inflammatory painkillers, which raise the bleeding risk in dengue",
            "Assuming you are recovering just because the fever broke -- days 3 to 7 are the risky ones",
            "Strenuous activity until you have fully recovered",
        ],
        "red_flags": [
            "Severe abdominal pain or persistent vomiting",
            "Bleeding gums or nose, or blood in vomit or stools",
            "Black tarry stools",
            "Cold clammy skin, restlessness or extreme weakness",
            "Passing little or no urine",
            "Any of these needs emergency care the same hour",
        ],
    },
    "diabetes": {
        "goal": "Keep glucose steady and protect your eyes, kidneys, nerves and feet long term.",
        "do": [
            "Eat at regular times, building meals around vegetables, whole grains and protein",
            "Aim for around 30 minutes of activity most days",
            "Check your feet daily for cuts, blisters and colour changes",
            "Monitor your glucose as your care team advised, and keep a record",
            "Attend your eye, kidney and foot screening appointments",
        ],
        "avoid": [
            "Sugary drinks and fruit juice, which spike glucose fastest",
            "Skipping meals, which destabilises control",
            "Walking barefoot, and leaving foot wounds unchecked",
            "Smoking, which multiplies the circulation risks",
        ],
        "red_flags": [
            "Shakiness, sweating, confusion or drowsiness -- possible low blood sugar, treat immediately",
            "Very high readings with thirst, frequent urination and vomiting",
            "Deep rapid breathing, or breath smelling sweet or fruity",
            "A foot wound that is not healing, or is red, swollen or discharging",
            "Sudden vision changes",
        ],
    },
    "dimorphic hemmorhoids(piles)": {
        "goal": "Soften stools and take the straining out of every trip to the toilet.",
        "do": [
            "Build up fibre gradually: vegetables, fruit, whole grains, pulses",
            "Drink plenty of water through the day",
            "Go as soon as you feel the urge rather than holding on",
            "Sit in a warm shallow bath for 10-15 minutes a few times a day",
            "Rest your feet on a low stool while on the toilet to straighten the passage",
        ],
        "avoid": [
            "Straining, and sitting on the toilet reading your phone",
            "Dry toilet paper -- use water or a damp wipe and pat dry",
            "Heavy lifting and long periods of sitting",
            "Very spicy food and alcohol if they flare your symptoms",
        ],
        "red_flags": [
            "Heavy or ongoing rectal bleeding",
            "A hard, extremely painful lump that will not reduce",
            "Bleeding with weight loss or a lasting change in bowel habit",
            "Black tarry stools",
            "Fever with anal pain or discharge",
        ],
    },
    "drug reaction": {
        "goal": "Stop the trigger safely and make sure it never gets given to you again.",
        "do": [
            "Contact the prescriber straight away -- do not stop an essential medicine on your own",
            "Write down the medicine name, the dose and when the reaction started",
            "Take a photo of any rash each day so the change is documented",
            "Apply cool compresses to irritated skin",
            "Make sure the reaction is added to your medical record and tell every future clinician",
        ],
        "avoid": [
            "Taking the suspected medicine again, or anything closely related to it",
            "Starting any new over-the-counter remedy until you have spoken to the prescriber",
            "Scratching affected skin",
        ],
        "red_flags": [
            "Swelling of the face, lips, tongue or throat, or trouble breathing",
            "Blistering or peeling skin, or sores in the mouth, eyes or genitals",
            "A rash with high fever and feeling very unwell",
            "Widespread rash spreading rapidly",
            "These are emergencies -- get help immediately",
        ],
    },
    "fungal infection": {
        "goal": "Keep the area clean and dry so it cannot come back.",
        "do": [
            "Wash the area daily and dry it thoroughly, especially in skin folds and between toes",
            "Wear loose cotton clothing and change socks daily",
            "Wash towels, socks and bedding hot, and use your own towel only",
            "Let the area air out when you can",
            "Complete the full course of any treatment you were prescribed, even after it looks clear",
        ],
        "avoid": [
            "Tight synthetic clothing and staying in damp clothes after sweating",
            "Sharing towels, shoes, combs or nail clippers",
            "Walking barefoot in communal showers and changing rooms",
            "Scratching, which spreads it to new areas",
        ],
        "red_flags": [
            "Spreading redness, warmth, swelling or pus",
            "Fever alongside the rash",
            "No improvement after two weeks of treatment",
            "Any fungal infection on the scalp or nails, or one in someone with diabetes",
        ],
    },
    "gastroenteritis": {
        "goal": "Stay hydrated -- with this illness, dehydration is the real danger, not the bug.",
        "do": [
            "Sip oral rehydration solution steadily, little and often",
            "Return to bland food as soon as you can manage it: rice, toast, bananas, plain potato",
            "Rest, and keep passing urine at a normal pale colour",
            "Wash hands with soap after every toilet visit and before food",
            "Stay off work or school until 48 hours after the last episode",
        ],
        "avoid": [
            "Fatty, fried, very spicy or very sugary food while symptoms last",
            "Alcohol, caffeine and fizzy drinks, which worsen fluid loss",
            "Anti-diarrhoeal medicines if you have a fever or blood in the stool -- check with a doctor first",
            "Preparing food for other people",
        ],
        "red_flags": [
            "Signs of dehydration: very little urine, sunken eyes, dizziness on standing",
            "Blood in the stool or vomit",
            "Unable to keep any fluid down for more than a few hours",
            "Severe or constant abdominal pain",
            "High fever, or symptoms lasting beyond a few days",
        ],
    },
    "gerd": {
        "goal": "Stop acid reaching the gullet, especially overnight.",
        "do": [
            "Eat smaller meals, more often, and eat slowly",
            "Finish eating at least three hours before lying down",
            "Raise the head of the bed by 15-20cm using blocks under the legs",
            "Work towards a healthy weight -- abdominal weight drives reflux directly",
            "Keep a food diary to identify your own triggers",
        ],
        "avoid": [
            "Fatty and fried food, chocolate, mint, citrus and tomato if they trigger you",
            "Coffee, alcohol, fizzy drinks and smoking",
            "Large evening meals and late-night snacks",
            "Tight belts and waistbands, and bending or lying down after eating",
        ],
        "red_flags": [
            "Difficulty or pain when swallowing, or food sticking",
            "Unintentional weight loss",
            "Vomiting blood, or black tarry stools",
            "Persistent vomiting, or new symptoms after age 50",
            "Chest pain with sweating or breathlessness -- treat as cardiac until proven otherwise",
        ],
    },
    "heart attack": {
        "goal": "This is a medical emergency. The priority is getting to hospital fast, not home care.",
        "do": [
            "Call emergency services now -- do not drive yourself",
            "Stop all activity and sit down, resting and supported",
            "Loosen tight clothing and stay as calm as you can",
            "Unlock the door so responders can reach you",
            "If you have been prescribed medication for chest pain, take it as instructed",
        ],
        "avoid": [
            "Waiting to see whether it passes -- minutes of delay cost heart muscle",
            "Driving yourself or being driven if an ambulance is available",
            "Eating or drinking anything",
            "Any physical exertion at all",
        ],
        "red_flags": [
            "Chest pressure, tightness or pain, possibly spreading to arm, jaw, neck or back",
            "Breathlessness, cold sweat, nausea or lightheadedness",
            "Symptoms that can be subtler in women, older adults and people with diabetes",
            "Call emergency services for any of these -- do not wait for certainty",
        ],
    },
    "hepatitis a": {
        "goal": "Rest your liver through the illness and avoid passing it to others.",
        "do": [
            "Rest -- fatigue is usually the longest-lasting part of this",
            "Drink fluids steadily and eat small, regular, low-fat meals",
            "Wash hands thoroughly after the toilet and before handling food",
            "Tell close contacts, who may benefit from vaccination",
            "Check with your doctor before taking any medicine, including painkillers",
        ],
        "avoid": [
            "Alcohol completely until your liver tests have returned to normal",
            "Preparing food for others while you are infectious",
            "Sharing towels, utensils or a toothbrush",
            "Paracetamol-containing products unless your doctor has confirmed the dose",
        ],
        "red_flags": [
            "Confusion, drowsiness or personality change",
            "Vomiting that stops you keeping fluids down",
            "Deepening jaundice, or severe abdominal swelling",
            "Easy bruising or bleeding",
            "Symptoms worsening after an initial improvement",
        ],
    },
    "hepatitis b": {
        "goal": "Stay in long-term monitoring and protect both your liver and the people around you.",
        "do": [
            "Keep your specialist follow-up and blood tests -- this needs monitoring even when you feel fine",
            "Make sure household and sexual contacts are tested and vaccinated",
            "Use condoms until partners are confirmed immune",
            "Eat a balanced diet and maintain a healthy weight",
            "Tell every clinician and dentist you see",
        ],
        "avoid": [
            "Alcohol, which accelerates liver damage substantially",
            "Sharing razors, toothbrushes, needles or nail clippers",
            "Donating blood, plasma or organs",
            "Herbal supplements and any new medicine without medical advice",
        ],
        "red_flags": [
            "Yellowing eyes or skin, or dark urine with pale stools",
            "Swelling of the abdomen or legs",
            "Vomiting blood, or black tarry stools",
            "Confusion, drowsiness or disturbed sleep",
            "Unexplained weight loss",
        ],
    },
    "hepatitis c": {
        "goal": "Get into treatment -- this is usually curable -- and protect the liver meanwhile.",
        "do": [
            "See a liver specialist about treatment; modern courses cure most people",
            "Attend monitoring blood tests and scans as arranged",
            "Ask about vaccination against hepatitis A and B",
            "Eat a balanced diet and keep to a healthy weight",
            "Tell every clinician and dentist you see",
        ],
        "avoid": [
            "Alcohol entirely -- it is the fastest route to scarring here",
            "Sharing razors, toothbrushes, needles or any injecting equipment",
            "Donating blood, plasma or organs",
            "Unsupervised supplements, which can add liver strain",
        ],
        "red_flags": [
            "Yellowing eyes or skin",
            "Abdominal swelling or swollen legs",
            "Vomiting blood, or black tarry stools",
            "Confusion or unusual drowsiness",
            "Severe fatigue with weight loss",
        ],
    },
    "hepatitis d": {
        "goal": "Keep both hepatitis D and the underlying hepatitis B under specialist review.",
        "do": [
            "Stay under specialist care -- this combination progresses faster than B alone",
            "Attend all monitoring blood tests and liver scans",
            "Make sure close contacts are vaccinated against hepatitis B",
            "Rest during flares and eat regular balanced meals",
            "Tell every clinician and dentist you see",
        ],
        "avoid": [
            "Alcohol in any amount",
            "Sharing razors, toothbrushes or needles",
            "Donating blood, plasma or organs",
            "Any new supplement or medicine without checking first",
        ],
        "red_flags": [
            "Rapidly deepening jaundice",
            "Abdominal swelling or swollen legs",
            "Vomiting blood, or black tarry stools",
            "Confusion, drowsiness or disturbed sleep",
            "Fever with shivering",
        ],
    },
    "hepatitis e": {
        "goal": "Rest through it, stay hydrated, and be extra careful if pregnant.",
        "do": [
            "Rest and drink safe, clean water steadily",
            "Eat small, light, low-fat meals",
            "Wash hands carefully after the toilet and before handling food",
            "Seek medical care promptly if you are pregnant -- hepatitis E is far more serious in pregnancy",
            "Check with a doctor before taking any medicine",
        ],
        "avoid": [
            "Alcohol until liver tests have normalised",
            "Untreated water, raw shellfish and undercooked pork or game",
            "Preparing food for other people while unwell",
        ],
        "red_flags": [
            "Confusion, drowsiness or personality change",
            "Persistent vomiting with no fluids staying down",
            "Deepening jaundice or abdominal swelling",
            "Easy bruising or bleeding",
            "Any symptoms at all during pregnancy -- get seen the same day",
        ],
    },
    "hypertension": {
        "goal": "Bring the pressure down steadily and protect your heart, brain and kidneys.",
        "do": [
            "Cut salt hard -- aim under 5g a day, and check labels on bread, sauces and snacks",
            "Build to 30 minutes of brisk activity most days",
            "Eat more vegetables, fruit, whole grains and pulses",
            "Check your pressure at home at the same time of day and keep a log",
            "Work on sleep and stress -- both raise readings genuinely, not just on the day",
        ],
        "avoid": [
            "Processed, tinned and takeaway food, where most hidden salt sits",
            "Excess alcohol, and smoking entirely",
            "Stopping prescribed treatment because you feel fine -- high pressure has no symptoms until it does damage",
            "Regular use of anti-inflammatory painkillers, which push pressure up",
        ],
        "red_flags": [
            "A reading above 180/120",
            "Severe headache with vision changes or confusion",
            "Chest pain or breathlessness",
            "Weakness or numbness on one side, or slurred speech",
            "Blood in the urine, or sudden swelling of the legs",
        ],
    },
    "hyperthyroidism": {
        "goal": "Take load off an overdriven system while treatment takes effect.",
        "do": [
            "Keep your endocrine appointments and blood tests -- dosing here needs tuning",
            "Eat enough: an overactive thyroid burns through calories and muscle",
            "Prioritise sleep and keep your room cool",
            "Use gentle exercise such as walking or yoga rather than intense training",
            "Ask about eye care if your eyes are gritty, bulging or watering",
        ],
        "avoid": [
            "Caffeine and energy drinks, which amplify the palpitations and tremor",
            "Iodine-rich supplements and kelp unless your doctor advised them",
            "Smoking, which markedly worsens thyroid eye disease",
            "High-intensity exercise while your heart rate is still fast",
        ],
        "red_flags": [
            "Fever with a racing pulse, agitation and confusion -- this is an emergency",
            "Chest pain, or a persistently irregular heartbeat",
            "Severe eye pain, double vision or losing vision",
            "Rapid unexplained weight loss with severe weakness",
        ],
    },
    "hypoglycemia": {
        "goal": "Treat the low now, then work out why it happened so it does not repeat.",
        "do": [
            "Take 15-20g of fast-acting sugar immediately: glucose tablets, juice or sugary drink",
            "Wait 15 minutes, re-check, and repeat once if still low",
            "Follow up with a longer-acting snack such as bread, fruit or milk",
            "Sit or lie down until you feel steady, and do not drive",
            "Log when lows happen, and review meals, activity and doses with your doctor",
        ],
        "avoid": [
            "Chocolate or fatty sweets to treat a low -- the fat slows the sugar down",
            "Skipping or delaying meals, and drinking alcohol on an empty stomach",
            "Going out or exercising without fast sugar on you",
            "Giving anything by mouth to someone who is drowsy or unconscious",
        ],
        "red_flags": [
            "Unconsciousness, a seizure, or being unable to swallow -- call emergency services",
            "A low that does not respond after two rounds of sugar",
            "Repeated lows, or lows you no longer feel coming",
            "Lows occurring at night or on waking",
        ],
    },
    "hypothyroidism": {
        "goal": "Get levels corrected and manage the fatigue while they settle.",
        "do": [
            "Take thyroid replacement exactly as directed, on an empty stomach, at the same time daily",
            "Keep the blood tests that guide your dose",
            "Eat a balanced diet with adequate iodine from normal food sources",
            "Stay gently active -- it helps the fatigue more than resting does",
            "Moisturise dry skin and keep warm",
        ],
        "avoid": [
            "Taking calcium, iron or antacids within four hours of thyroid medication",
            "Stopping treatment once you feel better -- this is usually lifelong",
            "High-dose iodine or kelp supplements",
            "Assuming worsening tiredness is just life -- it often means the dose needs review",
        ],
        "red_flags": [
            "Extreme drowsiness, confusion or feeling very cold with slow breathing -- emergency",
            "Chest pain or a very slow pulse",
            "Severe swelling of the face, hands or legs",
            "Depression that is deepening, or thoughts of self-harm",
        ],
    },
    "impetigo": {
        "goal": "Clear the infection and stop it spreading through the household.",
        "do": [
            "Wash the crusts gently with warm soapy water and pat dry",
            "Keep the area covered loosely with gauze where you can",
            "Use a separate towel, flannel and bedding, and wash them hot",
            "Keep nails short and wash hands after touching the area",
            "Stay off school or work until 48 hours of treatment, or until crusts have gone",
        ],
        "avoid": [
            "Scratching or picking the crusts",
            "Sharing towels, bedding, razors or clothing",
            "Close contact sports and swimming until it clears",
            "Sending a child back to school while sores are still weeping",
        ],
        "red_flags": [
            "Spreading redness, swelling or warmth around the sores",
            "Fever or feeling generally unwell",
            "Sores getting larger or deeper, or not improving after 48 hours of treatment",
            "Dark or reduced urine, or swollen ankles, in the weeks afterwards",
        ],
    },
    "jaundice": {
        "goal": "Find the cause -- jaundice is a sign, not a diagnosis -- and protect the liver meanwhile.",
        "do": [
            "See a doctor to establish the cause; this always needs investigating",
            "Rest and drink fluids steadily",
            "Eat small, frequent, low-fat meals",
            "Note the colour of your urine and stools, which helps pinpoint the cause",
            "Bring a list of every medicine, supplement and herbal remedy you take",
        ],
        "avoid": [
            "Alcohol entirely",
            "Paracetamol and other medicines until a doctor has confirmed what is safe",
            "Herbal and bodybuilding supplements",
            "Fatty and fried food while symptoms last",
        ],
        "red_flags": [
            "Confusion, drowsiness or personality change",
            "Fever with shivering and upper abdominal pain",
            "Vomiting blood, or black tarry stools",
            "Severe abdominal pain or rapid abdominal swelling",
            "Easy bruising or bleeding",
        ],
    },
    "malaria": {
        "goal": "Get treated promptly and complete the course -- malaria can worsen very fast.",
        "do": [
            "Get tested and start treatment immediately; do not wait for the fever pattern to declare itself",
            "Complete the entire prescribed course even once you feel well",
            "Drink fluids steadily and rest",
            "Manage fever with tepid sponging and light clothing",
            "Sleep under an insecticide-treated net to break the transmission cycle",
        ],
        "avoid": [
            "Delaying treatment -- falciparum malaria can become severe within 24 hours",
            "Stopping the course early, which drives resistance and relapse",
            "Heavy, oily food while nauseated",
            "Mosquito exposure at dawn and dusk",
        ],
        "red_flags": [
            "Confusion, drowsiness, seizures or difficulty waking",
            "Difficulty breathing",
            "Passing very dark urine, or very little urine",
            "Persistent vomiting with no fluids staying down",
            "Yellowing of the eyes, or unusual bleeding",
            "Any of these means severe malaria -- emergency care now",
        ],
    },
    "migraine": {
        "goal": "Get through the attack, then reduce how often they come.",
        "do": [
            "Lie down in a dark, quiet room at the first sign and stay there",
            "Apply a cold cloth to your forehead or the back of your neck",
            "Sip water steadily -- dehydration both triggers and prolongs attacks",
            "Keep a trigger diary: sleep, meals, stress, hormones, foods, weather",
            "Keep sleep and meal times regular, including at weekends",
        ],
        "avoid": [
            "Screens, bright light and loud noise during an attack",
            "Skipping meals or sleep, which are among the most common triggers",
            "Alcohol, especially red wine, and aged cheeses if they trigger you",
            "Using painkillers on more than 10 days a month -- that itself causes daily headache",
        ],
        "red_flags": [
            "A sudden, severe headache that peaks within seconds -- the worst of your life",
            "Headache with fever and a stiff neck",
            "Weakness, numbness, confusion or trouble speaking",
            "Headache after a head injury, or one worsened by coughing or lying flat",
            "A clear change in your usual headache pattern",
        ],
    },
    "osteoarthristis": {
        "goal": "Keep the joint working and slow the wear without triggering flares.",
        "do": [
            "Stay active with low-impact movement: walking, cycling, swimming, water exercise",
            "Strengthen the muscles around the joint -- this protects it more than rest does",
            "Lose excess weight if relevant; knee load falls by several kilos per kilo lost",
            "Use heat for stiffness and cold for swelling",
            "Use a stick, supportive footwear or a knee support where it helps",
        ],
        "avoid": [
            "Long periods of inactivity, which stiffen and weaken the joint",
            "High-impact activity such as running on hard surfaces during a flare",
            "Deep squatting, kneeling and stair-heavy routines if those hurt",
            "Pushing through sharp pain -- ache during exercise is fine, sharp pain is not",
        ],
        "red_flags": [
            "A joint that is hot, red and very swollen",
            "Joint pain with fever",
            "The joint locking, giving way or becoming unusable",
            "Pain that wakes you every night, or worsens rapidly",
            "Pain after a fall, with inability to bear weight",
        ],
    },
    "paralysis (brain hemorrhage)": {
        "goal": "This is a time-critical emergency. Every minute of delay costs brain tissue.",
        "do": [
            "Call emergency services immediately -- note the exact time symptoms began",
            "Lie the person down with head and shoulders slightly raised",
            "Turn them on their side if they are vomiting or unconscious",
            "Stay with them and keep them calm and still",
            "Keep a list of their medicines ready for the paramedics",
        ],
        "avoid": [
            "Giving food, drink or any medicine by mouth -- swallowing is often unsafe",
            "Waiting to see whether the weakness passes",
            "Driving them yourself if an ambulance can come",
            "Leaving them alone at any point",
        ],
        "red_flags": [
            "Face drooping on one side",
            "Arm or leg weakness on one side",
            "Slurred or confused speech",
            "Sudden severe headache, vomiting, or loss of consciousness",
            "Any one of these means call emergency services now",
        ],
    },
    "peptic ulcer diseae": {
        "goal": "Let the ulcer heal and remove what is keeping it open.",
        "do": [
            "Eat smaller, regular meals rather than large gaps followed by big meals",
            "Ask to be tested for H. pylori -- it causes most ulcers and is curable",
            "Complete any prescribed course fully, even after the pain settles",
            "Raise the head of the bed if pain wakes you at night",
            "Manage stress and sleep, which measurably affect symptoms",
        ],
        "avoid": [
            "Anti-inflammatory painkillers and aspirin unless a doctor has said otherwise",
            "Smoking, which delays healing significantly",
            "Alcohol, strong coffee and very spicy food if they trigger you",
            "Late heavy meals and lying down straight after eating",
        ],
        "red_flags": [
            "Vomiting blood, or material that looks like coffee grounds",
            "Black, tarry or sticky stools",
            "Sudden severe abdominal pain with a rigid, board-like belly -- emergency",
            "Difficulty swallowing, or unintentional weight loss",
            "Dizziness, fainting or breathlessness, which may mean blood loss",
        ],
    },
    "pneumonia": {
        "goal": "Support your breathing and recovery, and watch closely for deterioration.",
        "do": [
            "Rest properly -- full recovery commonly takes several weeks",
            "Drink fluids steadily to keep secretions loose",
            "Complete the entire antibiotic course if one was prescribed",
            "Sit upright and take slow deep breaths hourly while awake",
            "Ask your doctor about pneumococcal and flu vaccination afterwards",
        ],
        "avoid": [
            "Smoking and smoky environments",
            "Suppressing a productive cough, which is clearing your lungs",
            "Returning to full activity while still breathless",
            "Stopping antibiotics early because you feel better",
        ],
        "red_flags": [
            "Breathlessness at rest, or breathing fast",
            "Lips or fingertips turning blue or grey",
            "Chest pain that is sharp and worse on breathing in",
            "Confusion or drowsiness, especially in older adults",
            "Coughing up blood, or a fever that will not settle",
        ],
    },
    "psoriasis": {
        "goal": "Calm the plaques and lengthen the gaps between flares.",
        "do": [
            "Moisturise generously and often, especially straight after bathing",
            "Use lukewarm baths with plain or oil-based products",
            "Get short, regular periods of natural sunlight -- ask your doctor how much is right",
            "Work on stress, sleep and weight, all of which affect flare frequency",
            "Keep a diary of what precedes flares: infections, stress, skin injury, weather",
        ],
        "avoid": [
            "Scratching or picking plaques -- skin injury seeds new patches",
            "Hot baths, harsh soaps and heavily fragranced products",
            "Smoking and heavy alcohol, both of which worsen psoriasis directly",
            "Letting skin dry out",
        ],
        "red_flags": [
            "Widespread redness covering most of the body, with fever or shivering -- emergency",
            "Pustules appearing suddenly across the skin",
            "Joint pain, stiffness or swelling, which may mean psoriatic arthritis",
            "Plaques becoming hot, weeping or crusted",
            "Low mood affecting daily life -- this deserves support too",
        ],
    },
    "tuberculosis": {
        "goal": "Complete the full course -- that is what cures TB -- and protect those around you.",
        "do": [
            "Take every prescribed dose for the entire course, typically six months or more",
            "Cover your mouth when coughing and dispose of tissues safely",
            "Keep rooms well ventilated with windows open",
            "Eat protein-rich meals; weight loss is part of the illness",
            "Make sure household contacts are screened",
        ],
        "avoid": [
            "Stopping treatment when you feel better -- this is what creates drug-resistant TB",
            "Crowded enclosed spaces while you are still infectious",
            "Alcohol, which adds liver risk on top of TB medication",
            "Smoking, which worsens lung damage and outcomes",
        ],
        "red_flags": [
            "Coughing up blood",
            "Worsening breathlessness or chest pain",
            "Yellowing of the eyes or skin, which may signal a drug reaction",
            "Severe vomiting, rash, or vision changes during treatment",
            "Continued weight loss or fever despite treatment",
        ],
    },
    "typhoid": {
        "goal": "Complete treatment, stay hydrated, and avoid passing it on through food and water.",
        "do": [
            "Complete the full antibiotic course exactly as prescribed",
            "Drink safe, clean fluids steadily -- boiled or bottled",
            "Eat soft, bland, easily digested food in small amounts",
            "Rest fully; relapse is common when people return to activity too early",
            "Wash hands thoroughly after the toilet and before handling food",
        ],
        "avoid": [
            "Preparing food for other people until cleared",
            "Untreated water, ice, raw salads and street food",
            "High-fibre and very spicy food while the bowel is inflamed",
            "Stopping antibiotics early, which causes relapse",
        ],
        "red_flags": [
            "Severe abdominal pain or a rigid, tender abdomen -- possible perforation, an emergency",
            "Blood in the stool, or black tarry stools",
            "Confusion, extreme drowsiness or delirium",
            "Persistent vomiting with no fluids staying down",
            "A fever that keeps climbing despite treatment",
        ],
    },
    "urinary tract infection": {
        "goal": "Flush the infection out and stop it climbing to the kidneys.",
        "do": [
            "Drink plenty of water through the day",
            "Pass urine as soon as you feel the urge, and empty fully",
            "Pass urine soon after sex",
            "Wipe front to back",
            "Complete the full antibiotic course if one was prescribed",
        ],
        "avoid": [
            "Holding urine for long periods",
            "Caffeine, alcohol and fizzy drinks, which irritate the bladder",
            "Scented soaps, bubble baths and douches",
            "Tight synthetic underwear -- cotton is better",
        ],
        "red_flags": [
            "Pain in the back or side below the ribs",
            "Fever with shivering or shaking chills",
            "Nausea and vomiting",
            "Blood in the urine",
            "Confusion, especially in older adults",
            "These suggest a kidney infection -- get seen the same day",
        ],
    },
    "varicose veins": {
        "goal": "Improve the return flow in your legs and prevent skin damage.",
        "do": [
            "Raise your legs above heart level for 15 minutes several times a day",
            "Walk regularly -- the calf muscle is what pumps blood back up",
            "Wear compression stockings if advised, putting them on before you get up",
            "Moisturise the skin on your lower legs daily",
            "Lose excess weight if relevant",
        ],
        "avoid": [
            "Standing or sitting still for long stretches -- move every 30 minutes",
            "Crossing your legs for long periods",
            "Very hot baths, saunas and prolonged sun on the legs",
            "Scratching the skin over the veins",
        ],
        "red_flags": [
            "A vein that is hot, hard, red and tender",
            "Sudden swelling in one leg with pain in the calf -- possible clot, get seen urgently",
            "An ulcer or a break in the skin near the ankle that is not healing",
            "Bleeding from a vein -- lie down, raise the leg and press firmly",
            "Skin around the ankle turning brown, hard or thickened",
        ],
    },
}


def get_care_plan(disease: Optional[str]) -> Dict[str, object]:
    """The care plan for a condition, or the general one if none is authored."""
    return CARE_PLANS.get(normalize_disease(disease), DEFAULT_CARE_PLAN)


def flatten(plan: Dict[str, object]) -> List[str]:
    """The plan as one bulleted list, for the plain-text chat transcript."""
    lines: List[str] = []
    for label, key in (("Do", "do"), ("Avoid", "avoid"), ("See a doctor if", "red_flags")):
        items = plan.get(key) or []
        if items:
            lines.append("{}:".format(label))
            lines.extend("  * {}".format(item) for item in items)
    return lines
