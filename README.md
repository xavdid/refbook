# Refbook
This is the informational and functional hub of the [International Referee Development Program](http://refdevelopment.com), an independant quidditch referee certification and standards body.

## About the Site
For the most part, the site is [Sinatra](http://www.sinatrarb.com)(ruby) rendering [HAML](http://haml.info) supported by a [Parse](http://parse.com) database. These tools are all wonderfully powerful and play together nicely, which made my job a lot easier.

## Features

### [Integrated Testing](http://refdevelopment.com/testing)
Our tests are proctored through [Classmarker](http://classmarker.com), which allows for randomized Q/A order, test metrics (test duration, for instance), and some helpful question insights (commonly missed questions, etc).

In the past, users signed up for the AR and SR tests through a google doc which had a link to the CM page. Upon completion, CM would tell them what they got wrong and it would periodically update our database (which was a gsheet). The HR test required payment, so upon submitting money through paypal, hopefuls had to wait for one of us to send them an email with their unique test link. We were usually pretty fast about it, but vacations and emergencies happen, so there tended to be delays of up to 48 hours.

Given these shortcomings, the IRDP wanted to accomplish a few specific goals with the new system:

* Never force an applicant to wait to take their test
* Make certification status information easy for both us and the general public to access
* Centralize the requirements for the tests (waiting period, cost, qualification) so we (by hand) didn't have to check 3 google docs to validate whether a candidate should have taken a test.
* Make it super straightforward to test, regardless of what language(s) the user spoke.

The best way to store and reference this information is through an authenticated database. Because an account is required to attempt a test, we're able to easily track (and enforce) not only who they are and their team affiliation, but which tests they're qualified for and the time between attempts. Additionally, we can programmatically send confirmation emails and keep in touch with applicants.

### [Referee Directory](http://refdevelopment.com/search/ALL)
One of the challenges when planning a tournament is ref coordination. Part of the issue is knowing which of the 150 people showing up to your tournament are ref certified and in what capacity. In the past, TD's have posted referee signup forms on their event page in the hopes that refs reveal themselves for easy contact.

Instead, what if the TD could easy glance at their region and see a full, sortable list of certified refs in their region (and their contact info). That's exactly what we've done with our ref directory. Because certification happens within our system, it's easy to show a sanitized view of our database for public consumption.

### [Referee Reviews](http://refdevelopment.com/review)
For referees to improve, it's important that they're given feedback on how they did during a game. While the IQA has had a reviews system, it was always hard to find (despite now many bit.ly's we had) and required a lot of typing. RDT also wasn't great at passing on review information to the refs, so the overall experience really never helped referees improve.

Our new review system is simple (10 questions including name and stuff!) and easy to access (top level link: refdevelopment.com/review). Furthermore, we as administrators are able to directly send the productive reviews to the ref's account on our site. This way, we will hopefully be able to track a marked improvement in skill development over time.

### Central Payments & Registration
Instead of having to pay through another site or worry about waiting for a human to process your testing payment, all payments are done in local currency through paypal. Paypal takes care of the database, so changes are always reflected immediately and without hassle.

### Internationality
Because the IRDP is a global organization, being able to easily display translated versions of all our pages was an important goal.

While we originally had a copy of each page in each language, we quickly realized this wasn't scaleable (not to mention any functional changes needed be made 3x). Instead, we moved all text into `text.json` and changed all of the haml layouts to use organized keys to display text. Even though translation takes time, functionality is consistent across languages because each page is only a single file.

The layout of the json, for example, is this:

	{
		"help_small": {
        	"EN": {
        		"paid": "This is paid content"
	        },
	        "FR": {
	        	"paid": "Ce contenu est payant"
	        },
	        "IT": {
	        	"paid": "Questo è un contenuto a pagamento"
	        }
        }
	}

## API
Though still in a pre-alpha state, we're developing an API so you can use some of the information in our database for your own projects! The routes are as follows:

* `/api/refs/:IDS`:: return basic info about certain refs. Takes a comma separated list of ref ids and returns a json object. For example, `http://refdevelopment.com/api/refs/NDrskOZtwl` yields

		{
			assRef: true,
			email: "email@gmail.com",
			firstName: "David",
			headRef: true,
			lastName: "Brownman",
			passedFieldTest: true,
			profPic: "http://files.parse.com/5a1b2718-8b9b-422f-86a8-cfc9465cbfa4/538b6f48-540b-4c14-ab21-eaad155a3645-1425654_10201546798646515_711026637_n.jpg",
			region: "USWE",
			snitchRef: true,
			team: "Michigan Quidditch",
			createdAt: "2014-03-31T07:38:41.928Z",
			updatedAt: "2014-10-01T09:15:02.988Z",
			objectId: "NDrskOZtwl",
			className: "_User"
		}

There will be more routes (including a way to easily surface those ids) soon &trade;.

## Development

You'll need Ruby installed. 2.2.5 is the current version, though it should be pretty flexible. Once you clone the repo, run `bundle install` to get the dependencies installed. You'll need a .env file, which has the keys and stuff you need. It'll look a lot like the `.env.example` file. If you're working with the IQA, you'll be able to get these values from Heroku.

Run the server (`ruby refbook.rb`) and you'll be on your way!

---

_Acronym Key_

* __HR, SR, AR__: Head, Snitch, and Assistant referee, respectively. The three levels of referee certification.
* __CM__: Classmarker, the testing software we use.
* __TD__: Tournament Director
* __IQA__: International Quidditch Association, the worldwide quidditch governing body. __Note:__ the organization known as the IQA until July 2014 rebranded into __USQ__ to continue their work as a US centric organization. At that time, a new IQA was formed.
