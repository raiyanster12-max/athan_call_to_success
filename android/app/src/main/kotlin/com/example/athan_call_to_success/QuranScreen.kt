package com.example.athan_call_to_success

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template

/**
 * Android Auto screen that lists all 114 surahs of the Quran.
 *
 * Tapping a surah shows a [SurahDetailScreen] with its name and a prompt to
 * open the phone app for the full text – keeping the in-car experience
 * distraction-optimised.
 */
class QuranScreen(carContext: CarContext) : Screen(carContext) {

    override fun onGetTemplate(): Template {
        val listBuilder = ItemList.Builder()

        SURAHS.forEachIndexed { index, (arabic, english) ->
            listBuilder.addItem(
                Row.Builder()
                    .setTitle("${index + 1}. $english")
                    .addText(arabic)
                    .setOnClickListener {
                        screenManager.push(
                            SurahDetailScreen(carContext, index + 1, arabic, english)
                        )
                    }
                    .build()
            )
        }

        return ListTemplate.Builder()
            .setTitle("Quran")
            .setHeaderAction(Action.BACK)
            .setSingleList(listBuilder.build())
            .build()
    }

    companion object {
        /** Pair of (Arabic name, English transliteration / translation). */
        val SURAHS: List<Pair<String, String>> = listOf(
            "الفاتحة" to "Al-Fatihah (The Opening)",
            "البقرة" to "Al-Baqarah (The Cow)",
            "آل عمران" to "Ali 'Imran (Family of Imran)",
            "النساء" to "An-Nisa (The Women)",
            "المائدة" to "Al-Ma'idah (The Table Spread)",
            "الأنعام" to "Al-An'am (The Cattle)",
            "الأعراف" to "Al-A'raf (The Heights)",
            "الأنفال" to "Al-Anfal (The Spoils of War)",
            "التوبة" to "At-Tawbah (The Repentance)",
            "يونس" to "Yunus (Jonah)",
            "هود" to "Hud (Hud)",
            "يوسف" to "Yusuf (Joseph)",
            "الرعد" to "Ar-Ra'd (The Thunder)",
            "إبراهيم" to "Ibrahim (Abraham)",
            "الحجر" to "Al-Hijr (The Rocky Tract)",
            "النحل" to "An-Nahl (The Bee)",
            "الإسراء" to "Al-Isra (The Night Journey)",
            "الكهف" to "Al-Kahf (The Cave)",
            "مريم" to "Maryam (Mary)",
            "طه" to "Ta-Ha",
            "الأنبياء" to "Al-Anbiya (The Prophets)",
            "الحج" to "Al-Hajj (The Pilgrimage)",
            "المؤمنون" to "Al-Mu'minun (The Believers)",
            "النور" to "An-Nur (The Light)",
            "الفرقان" to "Al-Furqan (The Criterion)",
            "الشعراء" to "Ash-Shu'ara (The Poets)",
            "النمل" to "An-Naml (The Ant)",
            "القصص" to "Al-Qasas (The Stories)",
            "العنكبوت" to "Al-'Ankabut (The Spider)",
            "الروم" to "Ar-Rum (The Romans)",
            "لقمان" to "Luqman (Luqman)",
            "السجدة" to "As-Sajdah (The Prostration)",
            "الأحزاب" to "Al-Ahzab (The Combined Forces)",
            "سبأ" to "Saba (Sheba)",
            "فاطر" to "Fatir (Originator)",
            "يس" to "Ya-Sin",
            "الصافات" to "As-Saffat (Those Who Set the Ranks)",
            "ص" to "Sad",
            "الزمر" to "Az-Zumar (The Troops)",
            "غافر" to "Ghafir (The Forgiver)",
            "فصلت" to "Fussilat (Explained in Detail)",
            "الشورى" to "Ash-Shura (The Consultation)",
            "الزخرف" to "Az-Zukhruf (The Ornaments of Gold)",
            "الدخان" to "Ad-Dukhan (The Smoke)",
            "الجاثية" to "Al-Jathiyah (The Crouching)",
            "الأحقاف" to "Al-Ahqaf (The Wind-Curved Sandhills)",
            "محمد" to "Muhammad",
            "الفتح" to "Al-Fath (The Victory)",
            "الحجرات" to "Al-Hujurat (The Rooms)",
            "ق" to "Qaf",
            "الذاريات" to "Adh-Dhariyat (The Winnowing Winds)",
            "الطور" to "At-Tur (The Mount)",
            "النجم" to "An-Najm (The Star)",
            "القمر" to "Al-Qamar (The Moon)",
            "الرحمن" to "Ar-Rahman (The Beneficent)",
            "الواقعة" to "Al-Waqi'ah (The Inevitable)",
            "الحديد" to "Al-Hadid (The Iron)",
            "المجادلة" to "Al-Mujadila (The Pleading Woman)",
            "الحشر" to "Al-Hashr (The Exile)",
            "الممتحنة" to "Al-Mumtahanah (She That Is to Be Examined)",
            "الصف" to "As-Saff (The Ranks)",
            "الجمعة" to "Al-Jumu'ah (The Congregation, Friday)",
            "المنافقون" to "Al-Munafiqun (The Hypocrites)",
            "التغابن" to "At-Taghabun (The Mutual Disillusion)",
            "الطلاق" to "At-Talaq (The Divorce)",
            "التحريم" to "At-Tahrim (The Prohibition)",
            "الملك" to "Al-Mulk (The Sovereignty)",
            "القلم" to "Al-Qalam (The Pen)",
            "الحاقة" to "Al-Haqqah (The Reality)",
            "المعارج" to "Al-Ma'arij (The Ascending Stairways)",
            "نوح" to "Nuh (Noah)",
            "الجن" to "Al-Jinn (The Jinn)",
            "المزمل" to "Al-Muzzammil (The Enshrouded One)",
            "المدثر" to "Al-Muddaththir (The Cloaked One)",
            "القيامة" to "Al-Qiyamah (The Resurrection)",
            "الإنسان" to "Al-Insan (The Man)",
            "المرسلات" to "Al-Mursalat (The Emissaries)",
            "النبأ" to "An-Naba (The Tidings)",
            "النازعات" to "An-Nazi'at (Those Who Drag Forth)",
            "عبس" to "'Abasa (He Frowned)",
            "التكوير" to "At-Takwir (The Overthrowing)",
            "الانفطار" to "Al-Infitar (The Cleaving)",
            "المطففين" to "Al-Mutaffifin (The Defrauding)",
            "الانشقاق" to "Al-Inshiqaq (The Sundering)",
            "البروج" to "Al-Buruj (The Mansions of the Stars)",
            "الطارق" to "At-Tariq (The Nightcomer)",
            "الأعلى" to "Al-A'la (The Most High)",
            "الغاشية" to "Al-Ghashiyah (The Overwhelming)",
            "الفجر" to "Al-Fajr (The Dawn)",
            "البلد" to "Al-Balad (The City)",
            "الشمس" to "Ash-Shams (The Sun)",
            "الليل" to "Al-Layl (The Night)",
            "الضحى" to "Ad-Duha (The Morning Hours)",
            "الشرح" to "Ash-Sharh (The Relief)",
            "التين" to "At-Tin (The Fig)",
            "العلق" to "Al-'Alaq (The Clot)",
            "القدر" to "Al-Qadr (The Power)",
            "البينة" to "Al-Bayyinah (The Clear Proof)",
            "الزلزلة" to "Az-Zalzalah (The Earthquake)",
            "العاديات" to "Al-'Adiyat (The Courser)",
            "القارعة" to "Al-Qari'ah (The Calamity)",
            "التكاثر" to "At-Takathur (The Rivalry in World Increase)",
            "العصر" to "Al-'Asr (The Declining Day)",
            "الهمزة" to "Al-Humazah (The Traducer)",
            "الفيل" to "Al-Fil (The Elephant)",
            "قريش" to "Quraysh (Quraysh)",
            "الماعون" to "Al-Ma'un (The Small Kindnesses)",
            "الكوثر" to "Al-Kawthar (The Abundance)",
            "الكافرون" to "Al-Kafirun (The Disbelievers)",
            "النصر" to "An-Nasr (The Divine Support)",
            "المسد" to "Al-Masad (The Palm Fibre)",
            "الإخلاص" to "Al-Ikhlas (The Sincerity)",
            "الفلق" to "Al-Falaq (The Daybreak)",
            "الناس" to "An-Nas (The Mankind)"
        )
    }
}

/**
 * Detail screen shown when a surah is selected in [QuranScreen].
 *
 * Because displaying full Quran text on a car screen is unsafe for drivers,
 * this screen shows the surah name and guides the user to the phone app for
 * the complete reading experience.
 */
class SurahDetailScreen(
    carContext: CarContext,
    private val number: Int,
    private val arabic: String,
    private val english: String,
) : Screen(carContext) {

    override fun onGetTemplate(): Template {
        val message = "$arabic\n\nSurah $number of 114\n\n" +
                "Open the Athan app on your phone to read the full text of this surah."

        return MessageTemplate.Builder(message)
            .setTitle(english.substringBefore(" (", english))
            .setHeaderAction(Action.BACK)
            .addAction(
                Action.Builder()
                    .setTitle("Back to Quran")
                    .setOnClickListener { screenManager.pop() }
                    .build()
            )
            .build()
    }
}
