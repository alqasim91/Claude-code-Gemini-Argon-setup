# كلود يخطط وGemini 4 Argon يبرمج: الإعداد على الماك مع agy

<div dir="rtl">

Claude Code (تطبيق الديسكتوب، موديل Opus) بيخطط ويراجع ويتحقق. و Gemini 4 Argon هو اللي بيكتب الكود عن طريق أداة Antigravity CLI من Google، واسمها `agy`. اتبع الخطوات بالترتيب، وانسخ كل أمر زي ما هو بالظبط.

## هتحتاج إيه

- ماك
- تطبيق Claude Code للديسكتوب
- اشتراك Google AI Pro. Argon محتاج خطة AI Pro مش تجريبية، والكوتا بتاعته بتتجدد كل خمس ساعات، لحد حد أسبوعي.

## الخطوة صفر: ثبّت agy وسجّل دخول

1. افتح Terminal (دوس Cmd+Space واكتب Terminal ودوس Return) وشغّل أمر التثبيت بتاع Google:

</div>

```
curl -fsSL https://antigravity.google/cli/install.sh | bash
```

<div dir="rtl">

2. اتأكد إن التثبيت تمام. الملف التنفيذي بيتحط في `~/.local/bin/agy`.

</div>

```
agy --version
```

<div dir="rtl">

3. سجّل دخول. شغّل `agy`، وفي قائمة تسجيل الدخول اكتب `1` (Google OAuth). المتصفح هيفتح، سجّل دخول بحساب Google AI Pro بتاعك، وانسخ الكود وحطه في الـ Terminal ودوس Return.

</div>

```
agy
```

<div dir="rtl">

4. اعرض الموديلات وانسخ اسم Argon بالظبط:

</div>

```
agy models
```

<div dir="rtl">

## الخطوة 1: اعمل فولدر المشروع

في Finder، افتح فولدر المستخدم بتاعك وبعدين `Projects` (أو دوس Cmd+Shift+H وافتح `Projects`). اختار File > New Folder (أو دوس Shift+Cmd+N)، واكتب `my-app` ودوس Return. الفولدر هيكون `~/Projects/my-app`.

## الخطوة 2: اعمل الملفين

اعمل ملفين نصيين عاديين بالمحتوى اللي تحت بالظبط، وحطهم الاتنين جوه `my-app`. (في الفيديو بيتسحبوا من Downloads.)

في ملف `argon-builder.md` بدّل `gemini-4-argon` بالاسم بالظبط زي ما ظهر في `agy models`.

**CLAUDE.md**

</div>

```md
# Delegation rule
You (Claude) plan, review and verify. You do not write implementation code.
1. Plan: break the task into steps with acceptance criteria.
2. Delegate implementation to the argon-builder agent, one full spec per call.
3. Review the files it changed against each criterion; send fixes back through argon-builder.
4. Deliver only verified work.
```

<div dir="rtl">

**argon-builder.md**

</div>

```md
---
name: argon-builder
description: Hands implementation specs to Gemini 4 Argon through agy and reports back.
tools: Bash, Read
---
Run: agy -p "<full spec + acceptance criteria>" --model gemini-4-argon --print-timeout 20m < /dev/null
For fixes: agy -c -p "<fixes>" < /dev/null
Tell Argon to write every file in full, with no placeholders. Return the list of files it changed.
```

<div dir="rtl">

## الخطوة 3: شغّل أمر واحد

1. في Finder، اضغط كليك يمين على فولدر `my-app` واختار **New Terminal at Folder**.
2. لو مش لاقيه، دوّر عليه تحت **Services**، أو فعّله من System Settings > Keyboard > Keyboard Shortcuts > Services.
3. الصق الأمر ده ودوس Return:

</div>

```
mkdir -p .claude/agents && find . -maxdepth 1 -name "*.md" ! -name "CLAUDE.md" -exec mv {} .claude/agents/ \;
```

<div dir="rtl">

الأمر ده بيعمل فولدر مخفي اسمه `.claude`، وبينقل كل ملفات الـ markdown التانية جوه `.claude/agents/`، فملف `CLAUDE.md` بس هو اللي يفضل ظاهر في `my-app`. للتأكد، افتح `my-app` في Finder ودوس **Cmd+Shift+.** عشان تظهر الملفات المخفية، وهتلاقي `.claude/agents/argon-builder.md`.

## الخطوة 4: افتح سيشن جديدة

افتح تطبيق Claude Code للديسكتوب (من Applications، أو دوس Cmd+Space) واضغط **New session** فوق في الشريط الجانبي.

## الخطوة 5: اختار الفولدر وOpus

1. دوس على زرار الفولدر تحت صندوق الرسالة. في نافذة الاختيار اختار `Projects`، وبعدين `my-app`، وبعدين **Open**.
2. دوس على اختيار الموديل تحت صندوق الرسالة، واختار **Opus**، وهو المخطط.

## الخطوة 6: ابعت البرومبت

اكتب البرومبت ده وابعته:

</div>

```
Build a one-page landing page for my AI course with a signup form.
```

<div dir="rtl">

كلود مش هيبدأ يكتب كود. هو هيعمل خطة بمعايير قبول، وبعدين يسلّم لـ Argon بتشغيل `agy` بدون واجهة، بالأمر ده من ملف `argon-builder.md`:

</div>

```
agy -p "Build index.html: a one-page landing page for my AI course with a signup form. Criteria: single file, works at phone width, signup form validates the email, no placeholder text." --model gemini-4-argon --print-timeout 20m < /dev/null
```

<div dir="rtl">

بعد كده كلود بيقرا الملف اللي اتغيّر ويتأكد من كل معيار. لو معيار مش متحقق، بيبعت التصليح بـ `agy -c`، وده بيكمّل نفس المحادثة:

</div>

```
agy -c -p "Fix: validate the email field before submit and show an error message." < /dev/null
```

<div dir="rtl">

كلود بيراجع الملف تاني ومبيسلّمش غير شغل متحقَّق منه.

## لو حصلت مشكلة

- **agy: command not found.** افتح نافذة Terminal جديدة، أو اتأكد إن `~/.local/bin` موجود في الـ PATH.
- **Argon مش ظاهر في `agy models`.** Argon محتاج خطة Google AI Pro مش تجريبية.
- **الشغل الكبير بيخلص وقته.** زوّد `--print-timeout` (المثال بيستخدم `20m`).
- **`.claude` مش ظاهر في Finder.** الفولدرات اللي بتبدأ بنقطة مخفية على macOS. دوس Cmd+Shift+. في نافذة Finder عشان تظهرها أو تخفيها.

</div>

