# Refbook
This is the informational and functional hub of the [International Referee Development Program](http://refdevelopment.com), an independant quidditch referee certification and standards body. 

## About the Site
For the most part, the site is [Sinatra](http://www.sinatrarb.com)(ruby) rendering [HAML](http://haml.info) supported by a [Parse](http://parse.com) database. These tools are all wonderfully powerful and play together nicely, which made my job a lot easier. 

## Features
    
### [Integrated Testing](http://refdevelopment.com/testing)
Our tests are proctored through [Classmarker](http://classmarker.com), which allows for randomized Q/A order, test metrics (test duration, for instance), and some helpful question insights (commonly missed questions, etc). 

In the past, users signed up for the AR and SR tests through a google doc which had a link to the CM page. Upon completion, CM would tell them what they got wrong and it would periodically update our database (which was a gsheet). The HR test required payment, so upon submitting money through paypal, hopefuls had to wait for one of us to send them an email with their unique test link. We were usually pretty fast about it, but vacations and emergencies happen, so there tended to be delays of up to 48 hours. 

Given these shortcomings, I wanted to accomplish a few specific goals with the new system: 

* Never force an applicant wait to take their test
* Make certification status information easy for both us and the general public to access
* Centralize the requirements for the tests (waiting period, cost, qualification) so we (by hand) didn't have to check 3 google docs to validate whether a candidate should have taken a test.
* Make it super straightforward to test, regardless of what language(s) the user spoke.

The best way to store and reference this information is through an authenticated database. Because an account is required to attempt a test, we're able to easily track (and enforce) not only who they are and their team affiliation, but which tests they're qualified for and the time between attempts. Additionally, we can programmatically send confirmation emails and keep in touch with applicants.

### [Referee Directory](http://refdevelopment.com/search/ALL)
One of the challenges when planning a tournament is ref coordination. Part of the issue is knowing which of the 150 people showing up to your tournament are ref certified (and in what capacity) and in what capacity. In the past, TD's have posted referee signup forms on their event page in the hopes that refs reveal themselves for easy contact. 

Instead, what if the TD could easy glance at their region and see a full, sortable list of certified refs in their region (and their contact info). That's exactly what we've done with our ref directory. Because certification happens within our system, it's easy to show a sanitized view of our database for public consumption. 

### [Referee Reviews](http://refdevelopment.com/review)
For referees to improve, it's important that they're given feedback on how they did during a game. While the IQA has had a reviews system, it was always hard to find (despite now many bit.ly's we had) and required a lot of typing. RDT also wasn't great at passing on review information to the refs, so the overall experience really never helped referees improve. 

Our new review system is simple (10 questions including name and stuff!) and easy to access (top level link: refdevelopment.com/review). Furthermore, we as administrators are able to directly send the productive reviews to the ref's account on our site. This way, we will hopefully be able to track a marked improvement in skill development over time.

### Internationality
Because the IRDP is a global organization, being able to easily display translated versions of all our pages was an important goal. 

When HAML renders a page, all it needs is a symbol that represents the file, so with some clever helper methods we can extensibly render all versions of a page with a single controller.

    # part of the display helper, with filesystem map    
    
    # |-- /EN
    #   |--a.haml
    #   |--b.haml
    # |-- /FR
    #   |--a.haml
    #   |--b.haml
    
    haml "#{@lang}/#{path}".to_sym, layout: "#{@lang}/layout".to_sym
    
## Contributions
Want to help? Because a lot of the database info is very sensitive, it's hard to get local copies working for other developers. If you've got a great idea for a feature, feel free to open an issue or [contact](mailto:beamneocube@gmail.com?subject=Ref%20Dev%20Feature) me personally. If you're really devoted to progressing reffing standards around the world and have web dev experience (especially with either the technologies we use), reach out to me and we'll talk about a volunteer position with the IRDP.

---
_Acronym Key_

* __HR, SR, AR__: Head, Snitch, and Assistant referee, respectively. The three levels of referee certification.
* __CM__: Classmarker, the testing software we use.
* __TD__: Tournament Director
* __IQA__: International Quidditch Association, the worldwide quidditch governing body. __Note:__ the organization known as the IQA until July 2014 rebranded into __USQ__ to continue their work as a US centric organization. At that time, a new IQA was formed. 