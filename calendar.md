---
layout: default
title: Calendar
permalink: /calendar/
---

<h1>Calendar</h1>

{% if site.calendar.id and site.calendar.id != "" %}
{% assign cal_src = site.calendar.id | url_encode %}
{% assign cal_tz = site.calendar.timezone | url_encode %}
<div class="calendar-frame">
  <iframe
    src="https://calendar.google.com/calendar/embed?src={{ cal_src }}&amp;ctz={{ cal_tz }}&amp;mode=MONTH&amp;showPrint=0"
    title="{{ site.title }} events calendar"
    loading="lazy"></iframe>
</div>
<p><a href="https://calendar.google.com/calendar/u/0?cid={{ cal_src }}">Add this calendar to Google Calendar</a></p>
{% else %}
<p class="notice">Our events calendar is coming soon.</p>
{% endif %}
