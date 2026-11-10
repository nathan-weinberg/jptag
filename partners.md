---
layout: default
title: Partners
permalink: /partners/
---

<h1>Partners</h1>
<p class="lede">Organizations we work alongside for safer, greener, and more accessible transportation in Jamaica Plain and greater Boston.</p>

{% if site.data.partners and site.data.partners.size > 0 %}
<ul class="partner-list">
  {% for partner in site.data.partners %}
  <li class="partner">
    {% if partner.logo %}
    <img class="partner-logo" src="{{ partner.logo | relative_url }}" alt="{{ partner.name }} logo" width="72" height="72" loading="lazy">
    {% else %}
    <img class="partner-logo" src="{{ '/assets/img/partners/placeholder.svg' | relative_url }}" alt="" width="72" height="72" loading="lazy">
    {% endif %}
    <div>
      <h2><a href="{{ partner.url }}">{{ partner.name }}</a></h2>
      <p>{{ partner.description }}</p>
    </div>
  </li>
  {% endfor %}
</ul>
{% else %}
<p class="empty">No partners listed yet.</p>
{% endif %}
