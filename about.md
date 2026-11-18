---
layout: page
title: About
custom_header: true
description: "Who Allan Nava is: software and DevOps engineer at HiWay Media in Milan — Go services and the live video infrastructure they run on."
permalink: /about/
---

{%- comment -%}
The page recruiters open first: who, what, where, then the details. Built with nava-ui's
components (vendored in _sass/vendor/: nv-profile, nv-pill, nv-award); only the spacing
between sections is the site's own, in _sass/pages/page.sass. `custom_header: true` because
nv-profile carries the page's <h1>. No work history here: it is on the CV and LinkedIn, and a
third copy would drift; one sentence says where and since when. The profile links come from
`site.social.links`, never hard-coded.
{%- endcomment -%}

<header class="nv-profile">
  <img class="nv-profile__photo" src="{{ site.url }}/assets/images/profile_old.jpg" width="128" height="128" alt="">
  <div>
    <h1 class="nv-profile__name">Allan Nava</h1>
    <p class="nv-profile__role">Software &amp; DevOps engineer · Milan</p>
    <div class="nv-profile__actions">
      <a class="button button-primary" href="{{ site.url }}/projects/">See the projects</a>
      {%- for link in site.social.links -%}
        {%- if link contains "linkedin.com" %}
      <a class="button" href="{{ link }}" rel="me">LinkedIn</a>
        {%- elsif link contains "github.com" %}
      <a class="button" href="{{ link }}" rel="me">GitHub</a>
        {%- endif -%}
      {%- endfor %}
    </div>
  </div>
</header>

<p class="about-lead">I'm a software and DevOps engineer with over ten years in the industry — seven building web, mobile and backend products, nearly four running the infrastructure behind live video. I like owning both halves: writing the Go service, and keeping it up when the match-day traffic arrives.</p>

<p>I've been at <a href="https://hiway.media">HiWay Media</a> since 2020 — full stack until 2022, DevOps since 2023 — after nearly five years at IES Italia. The full history is on {% for link in site.social.links %}{% if link contains "linkedin.com" %}<a href="{{ link }}" rel="me">LinkedIn</a>{% endif %}{% endfor %}.</p>

<p class="about-focus">
  <span class="nv-pill nv-pill--accent"><span class="nv-mark nv-mark--dot" aria-hidden="true"></span>Go services</span>
  <span class="nv-pill nv-pill--accent"><span class="nv-mark nv-mark--dot" aria-hidden="true"></span>Live video infrastructure</span>
  <span class="nv-pill nv-pill--accent"><span class="nv-mark nv-mark--dot" aria-hidden="true"></span>Nomad and Consul</span>
  <span class="nv-pill nv-pill--accent"><span class="nv-mark nv-mark--dot" aria-hidden="true"></span>Keycloak and identity</span>
  <span class="nv-pill nv-pill--accent"><span class="nv-mark nv-mark--dot" aria-hidden="true"></span>Incident response</span>
</p>

<section class="about-section" aria-labelledby="recognition">
  <h2 id="recognition">Recognition</h2>
  <aside class="nv-award" aria-label="Award">
    <svg class="nv-award__mark" viewBox="0 0 48 48" aria-hidden="true" focusable="false"><path d="M15 3h7l4 11-6 3zM33 3h-7l-4 11 6 3z" fill="currentColor" opacity=".55"/><circle cx="24" cy="30" r="13" fill="none" stroke="currentColor" stroke-width="3"/><path d="M24 22.5l2.3 4.7 5.2.8-3.8 3.6.9 5.1-4.6-2.4-4.6 2.4.9-5.1-3.8-3.6 5.2-.8z" fill="currentColor"/></svg>
    <div>
      <p class="nv-award__kicker">Award · 2025</p>
      <p class="nv-award__title">Gold — Best New Platform</p>
      <p class="nv-award__text">SportsPro Media Awards 2025, to Sevilla FC+, the club's OTT platform built at HiWay Media. I'm part of the team behind it.</p>
      <a class="nv-award__link" href="{{ site.url }}{% post_url 2025-11-20-allan-nava-sevillafc-sportspro-award %}">The story →</a>
    </div>
  </aside>
</section>

<section class="about-section" aria-labelledby="what-i-do">
  <h2 id="what-i-do">What I do</h2>

  <p>On the software side I write Go microservices designed with domain-driven design, and the Sign in with Apple and Druid identity providers for Keycloak in Java. On the infrastructure side I run a HashiCorp stack (Nomad, Consul, Traefik), NATS, Keycloak, Ansible and TeamCity for broadcasting, distribution and OTT platforms in sports, music and entertainment.</p>

  <p>Live video has no maintenance window, so most of my work happens before the event: k6 load tests that simulate match-day traffic, so capacity problems show up in testing and not during a live match; Go tooling around Nomad and the encoders; a health-check platform, released as <a href="https://github.com/Allan-Nava/checkfleet">checkfleet</a>. When an incident does happen in production, I run the response and write the post-mortem.</p>

  <p>The <a href="{{ site.url }}/stack/">stack</a> page lists what I work with and where I used each one; the <a href="{{ site.url }}/projects/">projects</a> page catalogues what I build and run, most of it open source on GitHub.</p>
</section>

<section class="about-section" aria-labelledby="outside-work">
  <h2 id="outside-work">Outside work</h2>
  <p>Climbing, snowboarding, workouts, travel and videogames — some of it is in the <a href="{{ site.url }}/videos/">videos</a>.</p>
</section>
