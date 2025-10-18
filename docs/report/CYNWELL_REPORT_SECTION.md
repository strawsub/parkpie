## 1. Executive Summary
Finding on-street parking in urban areas remains a persistent challenge for drivers, compounded by the absence of a centralized database to inform them of parking availability, restrictions, and time limits. While existing paid applications like EasyPark and PayStay offer solutions, they are limited to managing only the parking spots within their own networks. Our application addresses this gap by providing a comprehensive, crowd-sourced parking information solution that covers all on-street parking locations.
The Smart Parking Assistant leverages a modern technology stack—Flutter for cross-platform mobile development, Java Spring Boot for robust backend services, Microsoft Azure for scalable cloud infrastructure, and Google Gemini AI for intelligent parking sign interpretation. By combining real-time parking detection, automated restriction tracking, and community-contributed data, the application eliminates the stress from urban parking.
What distinguishes this solution is its innovative approach to data collection and automation. Rather than relying on manual input or proprietary parking networks, the app crowdsources parking restriction information through AI-powered sign recognition and automatically tracks parking sessions using device sensors. This creates a self-sustaining ecosystem where every user contributes to and benefits from an increasingly comprehensive parking database.
## 2. Application Overview
### 2.1	Purpose and Scope
The Smart Parking Assistant is designed to serve urban commuters and drivers who regularly navigate the complexities of on-street parking in metropolitan and suburban areas. The application addresses several critical pain points in the current parking ecosystem: the lack of centralized parking information, difficulty interpreting complex parking signage, the risk of exceeding time limits and incurring fines, and uncertainty about parking availability in unfamiliar areas.
Traditional parking solutions fall into two categories: government-managed parking meters with limited digital integration and uniformity, and private parking apps that only cover specific commercial lots. This leaves the vast majority of on-street parking restrictions effectively invisible to digital systems. Our application bridges this gap by creating a comprehensive, user-maintained database that has the potential to cover all public parking spaces.
The solution employs a collaborative approach where users both contribute to and benefit from shared parking intelligence. By scanning parking signs, confirming parking locations, and allowing the app to track parking sessions, users help build a detailed map of parking restrictions that serves the entire community. This crowdsourced model ensures the database remains current and expands organically as users explore new areas.
### 2.2	Key Features
1.	Interactive Parking Map: The core feature presents a geospatial view of parking locations with pins indicating parking restrictions by day of the week and time of day. Users can filter results based on their parking duration needs and search for suitable spots in advance of their journey. The map displays crucial information including time limits (e.g., 2-hour parking), restricted hours (e.g., no parking 4-6 PM), and day-specific variations. This allows drivers to plan their parking strategy before reaching their destination, reducing time spent circling for suitable spots.
2.	AI-Powered Sign Recognition: Parking signage can be complex, often featuring multiple overlapping restrictions, conditional rules, and unclear temporal boundaries. Our Gemini-powered scanning feature allows users to photograph parking signs and receive instant, plain-language interpretations of the restrictions. The AI extracts key information such as time limits and restricted periods. Critically, this information is then contributed to our crowdsourced database, continuously improving the accuracy and coverage of parking restriction data across the city.
3.	Automated Parking Timer: Manual parking timers require users to remember to set them and estimate their allowed duration. Our solution automates this process by detecting when a user has parked (using GPS, gyroscope, accelerometer and bluetooth sensors) and prompting for confirmation. Upon confirmation, the app automatically retrieves the applicable parking restrictions for that specific location, day, and time, then initiates a countdown timer. Push notifications alert users when their parking time is approaching expiration, with customizable warning intervals. This feature significantly reduces the risk of parking fines due to exceeded time limits.
4.	Real-Time Availability Information: Understanding parking availability before arrival saves time and reduces congestion from circling vehicles. For the City of Melbourne areas where official parking spot data is available through APIs, the app displays availability as a percentage (e.g.,“65% occupied”). For other suburban and regional areas, the app uses anonymized location data from app users to provide an absolute count of detected parked vehicles in specific segments. This crowdsourced availability data helps users identify which areas are currently experiencing high parking demand, enabling them to make informed decisions about where to search for parking.
### 2.3	Target Audience
The primary target audience comprises urban commuters who regularly navigate parking challenges in metropolitan and developing suburban areas. While the City of Melbourne represents an initial focus area with its complex CBD parking ecosystem, the application’s value proposition extends significantly beyond the traditional city center.
As government urban planning initiatives develop suburban activity centers in locations such as Clayton, Box Hill, Glen Waverley, and Footscray, these areas are experiencing increased commercial activity accompanied by parking constraints similar to those traditionally found only in CBDs. The application supports this urban evolution by providing parking intelligence for these emerging hotspots.
Beyond commercial centers, the app serves users at high-demand parking locations including train stations (where commuter parking is highly competitive during peak hours), shopping strips and retail precincts (especially during weekends and meal times), and sports and leisure centers (which experience concentrated demand during events and peak activity times). The flexible, crowdsourced nature of the database means the application remains valuable across diverse suburban and urban contexts, adapting to local parking patterns through community contribution.

## 3.1 Implementation Quality
Cynwell (backend only)
Guiding Questions:
Is the code readable, consistent, and well-formatted?
Are functions and variables clearly named?
Are there comments explaining non-obvious logic?

## 3.5 Implementation Technical Depth
Cynwell (Gemini prompt only)
Guiding Questions:
Are advanced algorithms implemented?
How are algorithms applied to sensing, localization, privacy, or communication?
What technical challenges were overcome?

## 5. Innovation
### 5.1 Innovation Novelty
Cynwell
Guiding Questions:
Does the app provide functionality that is new or different?
How is this functionality different from existing solutions?

### 5.2 Innovation Surprise
Cynwell
Guiding Questions:
Is there an unexpected or creative feature?
How might users react to this feature?

### 5.3 Innovation Tech Knowledge
Cynwell
Guiding Questions:
Does the app demonstrate knowledge in computing/information systems?
How is theoretical knowledge applied in the implementation?

### 5.4 Innovation Cross-Disciplinary
Cynwell
Guiding Questions:
Does the app apply knowledge from other fields (e.g., psychology, design, business)?
How is this knowledge integrated effectively?

### 5.5 Innovation Impact
Cynwell
Guiding Questions:
Could the app improve people’s lives, tasks, or activities?
Are there measurable or demonstrable benefits for users?
