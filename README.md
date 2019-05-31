<img src="http://www.soalition.com/logo.svg" width="92px" height="92px"/>

[![EO principles respected here](https://www.elegantobjects.org/badge.svg)](https://www.elegantobjects.org)
[![Managed by Zerocracy](https://www.0crat.com/badge/CAZPZR9FS.svg)](https://www.0crat.com/p/CAZPZR9FS)
[![DevOps By Rultor.com](http://www.rultor.com/b/yegor256/soalition)](http://www.rultor.com/p/yegor256/soalition)
[![We recommend RubyMine](https://www.elegantobjects.org/rubymine.svg)](https://www.jetbrains.com/ruby/)

[![Build Status](https://travis-ci.org/yegor256/soalition.svg)](https://travis-ci.org/yegor256/soalition)
[![PDD status](http://www.0pdd.com/svg?name=yegor256/soalition)](http://www.0pdd.com/p?name=yegor256/soalition)
[![Test Coverage](https://img.shields.io/codecov/c/github/yegor256/soalition.svg)](https://codecov.io/github/yegor256/soalition?branch=master)
[![Maintainability](https://api.codeclimate.com/v1/badges/451556110dacf73cc6f6/maintainability)](https://codeclimate.com/github/yegor256/soalition/maintainability)

[![Availability at SixNines](https://www.sixnines.io/b/79be)](https://www.sixnines.io/h/79be)
[![Hits-of-Code](https://hitsofcode.com/github/yegor256/soalition)](https://hitsofcode.com/view/github/yegor256/soalition)

It's a social coalition management web app for online writers.

Each _soalition_ (social coalition) is a group of Internet writers interested
in helping each other promote the same idea. They all write regularly
and want others in the group to share their content. In exchange they
are willing to share their content too.

Everybody has a _score_ inside a soalition, which is calculated by
the formula (see method `score()`
in [`soalition.rb`](https://github.com/yegor256/soalition/blob/master/objects/soalition.rb)):

S = R + (3 - |P - 3|) x M

Here, _R_ is the number of reposts a member of the group did in the last
90 days, _P_ is the number of posts a member shared with the group in the
same period of time, and _M_ is the number of members currently in the group.

The formula conveys the idea that each repost is a positive contribution,
while only the first three posts are positive. All other posts, which go above
the first three lower the score. In other words, to keep the score positive
a member of the group has to post once a month and repost all content
shared by other members.

## How to contribute

You will need Java 8, Maven 3.2+, Ruby 2.3+, Bundler.

Just run:

```bash
$ rake
```

To run a single test first run this, in a separate terminal:

```
$ rake pgsql liquibase sleep
```

This will start a PostgreSQL database, fill it up with the schema and stay
waiting. Then, in another terminal:

```
$ ruby test/test_soalition.rb
```

Should work :)
