---
layout: default
title: Home
---

<section class="hero">
  <h1>{{ site.title }}</h1>
  <p class="mission">{{ site.mission }}</p>

  {% if site.google_group.url and site.google_group.url != "" %}
  <a class="button" href="{{ site.google_group.url }}">Join our mailing list</a>
  {% else %}
  <p class="notice">Mailing list sign-up coming soon.</p>
  {% endif %}
</section>
