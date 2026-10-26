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

  {% if site.instagram_url and site.instagram_url != "" %}
  {% assign instagram_profile = site.instagram_url | remove_last: "/" | append: "/" %}
  <div class="instagram-embed">
    <blockquote class="instagram-media" data-instgrm-permalink="{{ instagram_profile }}" data-instgrm-version="14">
      <a href="{{ instagram_profile }}">View JPTAG on Instagram</a>
    </blockquote>
    <script async src="https://www.instagram.com/embed.js"></script>
  </div>
  {% endif %}
</section>
