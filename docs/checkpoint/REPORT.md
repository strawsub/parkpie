# COMP90018 Assignment Checkpoint Report
Group 3, Tutorial 10

## Team Members

| Name | Student Number | Email |
|------|----------------|-------|
| Thuy Khue Nguyen (Khue) | 1263494 | thuykhuen@student.unimelb.edu.au |
| Rungthip Chaothayee (Tan) | 1572000 | chaothayeer@student.unimelb.edu.au |
| Wasutum Kethom (Kwan) | 1537761| wkethom@student.unimelb.edu.au |
| Zhuofei Yan | 1638660 | zhuofeiyan@student.unimelb.edu.au |
| Huichun Lee (Gin) | 1535351 | huichun@student.unimelb.edu.au |
| Hsing-Wei Liao (Cynwell) | 1607270 | hsingweil@student.unimelb.edu.au |

## Project: Parkpie

We're building a mobile app that addresses the common driving problem of finding suitable parking. Our app combines crowd-sourced data collection with intelligent parking assistance, offering two main features:

1. Users can find on-street parking that matches their specific restrictions (time limits, permit requirements, vehicle type)
2. Users contribute to the database by photographing parking signs, which are processed using computer vision to extract restriction information

This approach differs from existing solutions like EasyPark (which only covers their own parking areas) or Google Maps (which doesn't provide detailed parking restrictions).

## Individual Contributions Plan

**Tan - User Interface**
- Create Figma prototypes and conduct user testing
- Design UI following iOS Human Interface Guidelines
- Implement responsive Flutter UI components

**Khue - Algorithms & Optimization**
- Implement parking sign detection and OCR functionality
- Develop algorithms to determine when car is parked
- Handle real-time image processing
- Implement state management for reactive UI

**Zhuofei - Cloud Services & Sensor Integration**
- Set up Microsoft Azure cloud infrastructure and database for entities
- Implement GPS tracking for location-based features
- Integrate accelerometer and Bluetooth for parking status detection

**Gin - Cloud Services & Sensor Integration**
- Set up Microsoft Azure cloud infrastructure and blob database for images
- Implement cloud service features in front-end
- Implement GPS location features in the front end
- Set up GPS location uploads to the cloud

**Kwan - Database Management & Backend Development**
- Integrate with City of Melbourne parking datasets
- Integrate user input information with database
- Fetch data from database to display on frontend

**Cynwell - Design & Backend Development**
- Design logo and other app assets
- Set up backend infrastructure using Spring Boot
- Set up backend dashboard for updating of database information
- Set up baseline Continuous Integration (CI) for both frontend and backend


## Material

### Material Report & Video (6 points)

The report will follow this document headings and subheadings to ensure that we cover all grading criteria, with screenshots, diagrams and explanations of key features. We will format the report in LaTeX for a more professional look.

The video will demonstrate the launching of the app, the core functionalities and selective advanced features. This process also showcases the user interactions and flow, as well as the app responsiveness. The voiceover will be consistent and clear.

### Screenshot (2 points)

Since we're developing for iOS, we will showcase a screenshot of the app in the emulator.

### Commit Log (4 points)

Our development is fully on GitHub, following the best practice commit message, such as 'feat(frontend): implement camera feature'.

### Itemised contributions (2 points)

Our itemised contributions mentioned above only include the past six weeks work. As the project progresses and work is allocated to members, we will keep track of the list and further expand it.


## Implementation

### Implementation Quality (10 points)
We're implementing a professional development workflow with CI/CD pipelines, mandatory code reviews, and comprehensive testing. Our Flutter app will follow clean architecture principles with the BLoC pattern for state management, ensuring modularized code. We'll use automated linting, formatting tools, and establish coding standards that all team members follow. The codebase will include comprehensive documentation and follow industry best practices for mobile app development.

### Implementation Sensors (10 points)
Our app integrates multiple sensors working together. The camera captures parking sign images for computer vision processing, currently using Gemini Flash Lite 2.5. GPS provides precise location data for finding nearby parking and determining user position relative to parking spots. The accelerometer detects when the user's car has stopped moving, indicating they may have parked, which helps update spot availability. Additionally, this feature allows the app to start the parking timer to assist user in keeping time in according with the parking restriction. In combination with the user calendar, the app can intelligently advise users on suitable parking spots, or give warnings for spots deemed unsuitable.

### Implementation Connectivity (12 points)

Our application is built on Microsoft Azure, which we use to store and manage the parking database. The City of Melbourne’s parking data is incorporated in two ways. First, we import parking restriction information into the database, making it easy to update when changes occur. Second, the app connects directly to the City of Melbourne’s public parking APIs, allowing us to retrieve real-time information about parking availability.

When a user takes a photo of a parking sign, the image is stored temporarily in Microsoft Azure Blob Storage. This ensures we can authenticate the photo before proceeding, while also keeping the process secure and efficient.

### Implementation Responsiveness (6 points)

Using Flutter's BLoC state management pattern with Cubit, our UI reactively updates based on sensor data and external information. For instance, whe users take photos of parking signs, they see real-time processing indicators. As the app responds to frequent user input, such as when moving the map, we use a debounce to prevent redundant API calls. We also implement parking availability as an API call to facilitate the most up-to-date information retrieval.

### Implementation Technical Depth (6 points)

With regards to the image capturing feature, we implement an intermediary processing and verification process to prevent redundant Gemini API call. This algorithm detects and authenticates that the image is of a rectangular parking sign. Additionally, user image is only kept for a short period for authenticaion and then deleted, which supports the privacy of the app.

The app uses GPS to detect user's location and cross-reference with the parking database. This localisation ensure the app only queries relevant parking availability.

Communication is optimized with low-latency API calls and caching mechanisms to reduce calls to the City of Melbourne database.


## User Interface

### User Interface Appeal (4 points)

We endeavour for a modern and minimal interface but with youthful energy (think Waze). Our design process includes studying successful navigation and parking apps like Google Maps, Waze, and EasyPark to understand what works well. We're creating detailed Figma prototypes and conducting user interviews to ensure our design resonates with users. The visual design emphasizes clarity and ease of use while maintaining an attractive, contemporary appearance that users will enjoy using.

### User Interface Guidelines (6 points)

Since we're developing for iOS, we'll strictly follow Apple's Human Interface Guidelines. This includes using standard iOS navigation patterns, respecting safe areas, implementing proper touch targets, and using system fonts and colors appropriately. We'll ensure our app feels native to iOS users by following established conventions for buttons, menus, gestures, and navigation flows. Accessibility will be built in from the start, supporting VoiceOver, Dynamic Type, and other iOS accessibility features.

### User Interface Flow (6 points)

Our app design prioritizes intuitive user flows based on real-world parking scenarios. Similarly, we will design the flow in Figma then invite users input. The goal is that users can quickly access core features - finding parking or reporting a spot - with minimal taps. We're applying established UX principles like progressive disclosure to avoid overwhelming users with too many options at once. The information architecture follows logical patterns that users expect from navigation apps. Error states and edge cases are handled gracefully with clear recovery paths.

### User Interface Language (4 points)

We're implementing proper L10n (localization) to support multiple languages, starting with English and expanding based on user demographics. All text is clear, concise, and action-oriented. We're conducting user testing to ensure our terminology makes sense to real users. Labels and messages provide context without being verbose, and error messages are helpful rather than technical. The language feels natural and conversational while remaining professional.

### User Interface Reactiveness (6 points)

The interface dynamically responds to sensor input and external data changes. When GPS detects the user is moving, the app updates nearby parking options in real-time. Camera input immediately triggers processing indicators and shows progress as sign recognition occurs. Location-based features automatically update content as users navigate through different areas. The app provides immediate feedback for all user actions, creating a responsive and engaging experience.

## Innovation

### Innovation Novelty (3 points)

Most existing parking apps either focus only on paid parking (EasyPark) or don't provide detailed restriction information (Google Maps). Our crowd-sourced approach creates a comprehensive database of on-street parking restrictions that benefits the entire community, a concept successfully implemented by the PetrolSpy app. The computer vision component allows users to easily contribute data by simply taking photos, making data collection effortless. This combination of community participation and advanced technology creates a novel solution to the canonical parking problem.

### Innovation Surprise (3 points)

Our app extends beyond traditional parking apps by turning every user into a data contributor. The gamification elements with incentives for photo submissions create unexpected engagement. Real-time parking availability updates based on sensor detection (knowing when cars actually leave spots) provides more accurate information than static databases. The combination of navigation assistance with detailed restriction analysis offers a comprehensive parking solution that doesn't currently exist in the market.

### Innovation Tech Knowledge (4 points)

The app demonstrates integration of multiple computing domains. Computer vision processes parking sign images and extracts structured data. Geospatial computing handles location-based search and proximity calculations. Privacy engineering protects sensitive user location data while still enabling useful features. Cloud computing provides scalable infrastructure for data storage and processing.

### Innovation Cross-Disciplinary (3 points)

Our project bridges computing and urban planning by tackling real city infrastructure challenges. We apply principles from behavioral psychology to design thoughtful incentives that encourage user participation. Transportation engineering concepts guide our interpretation of parking restrictions and road rules, ensuring accuracy and compliance. Finally, we simplify this complex information into a clear, user-friendly interface, making it accessible and actionable for everyday users.

### Innovation Impact (3 points)

ParkPie has genuine potential to improve daily urban life. Reducing time spent searching for parking decreases stress, saves fuel, and reduces traffic congestion. Helping users understand parking restrictions prevents tickets and fines. The crowd-sourced data model creates a public good that benefits everyone, not just paying customers of commercial parking companies. For users with accessibility needs, detailed restriction information helps them find appropriate parking more easily.

## Development Approach

We are taking an iterative, Agile approach to development. Our first prototypes concentrate on technically challenging but essential features, such as parking spot filtering and user contributions, which form the foundation of our value proposition. From there, we will incrementally introduce advanced features while continuously refining the user experience. Regular user testing sessions will guide our design decisions, ensuring that each iteration not only improves functionality but also aligns with real user needs and expectations.

This checkpoint represents our current planning, and we expect to refine details as we begin implementation and learn more about technical constraints and user needs.
