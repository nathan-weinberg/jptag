---
layout: default
title: Projects
permalink: /projects/
---

<h1>Projects</h1>
<p class="lede">Transportation projects we're following, grouped by corridor and the agency responsible.</p>

<nav class="toc" aria-label="Project sections">
  <ul>
    {% for section in site.data.projects.sections %}
    <li><a href="#{{ section.id }}">{{ section.title }}</a></li>
    {% endfor %}
  </ul>
</nav>

{% for section in site.data.projects.sections %}
<section class="project-section" id="{{ section.id }}">
  <h2>{{ section.title }}</h2>
  <p class="agency">Managed by the {{ section.agency }}</p>
  {% if section.note %}<p class="section-note">{{ section.note }}</p>{% endif %}

  {% if section.projects and section.projects.size > 0 %}
  <ul class="project-list">
    {% for project in section.projects %}
    <li class="project">
      <h3>
        <a href="{{ project.url }}">{{ project.title }}</a>
        {% if project.status %}<span class="status">{{ project.status }}</span>{% endif %}
      </h3>
      <p>{{ project.description }}</p>
    </li>
    {% endfor %}
  </ul>
  {% else %}
  <p class="empty">No active projects tracked right now.</p>
  {% endif %}
</section>
{% endfor %}

<p class="projects-footnote">
  These project lists are maintained manually by volunteers using official agency pages and may not reflect the latest changes.
  Information last updated {{ site.data.projects.last_updated | date: "%B %-d, %Y" }}.
</p>
