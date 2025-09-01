# COMP90018 Assignment Checkpoint Report
Group 3, Tutorial 10

## Team Members

| Name | Student Number | Email |
|------|----------------|-------|
| Thuy Khue Nguyen (Khue) | 1263494 | thuykhuen@student.unimelb.edu.au |
| Tan | [Student Number] | [Email] |
| Kwan | [Student Number] | [Email] |
| Zhuofei | [Student Number] | [Email] |
| Gin | 1535351 | huichun@student.unimelb.edu.au |
| Cynwell | [Student Number] | [Email] |

## Individual Contributions Plan

**Tan - User Interface**
- Design UI following iOS Human Interface Guidelines
- Create Figma prototypes and conduct user testing
- Implement responsive Flutter UI components

**Khue - Algorithms & Optimization**
- Implement parking sign detection and OCR functionality
- Develop algorithms to determine when car is parked
- Handle real-time image processing and data extraction
- Implement Cubit state management for reactive UI

**Zhuofei - Cloud Services & Sensor Integration**
- Set up Microsoft Azure cloud infrastructure and database for entities
- Implement GPS tracking for location-based features
- Integrate accelerometer and Bluetooth for parking detection

**Gin - Cloud Services & Sensor Integration**
- Set up Microsoft Azure cloud infrastructure and blob database for images
- Implement cloud service features in front-end
- Implement GPS location features in the front end
- Set up GPS location uploads to the cloud

**Kwan - Database Management & Backend**
- Integrate with City of Melbourne parking datasets
- Integrate user input information with database

**Cynwell - Design & Backend Development**
- Design logo and other app assets
- Set up backend dashboard for updating of database information


## Project Concept: SmartPark

We're building a mobile app that addresses the common urban problem of finding suitable parking. Our app combines crowd-sourced data collection with intelligent parking assistance, offering two main features:

1. Users can find on-street parking that matches their specific restrictions (time limits, permit requirements, vehicle type)
2. Users contribute to the database by photographing parking signs, which are processed using computer vision to extract restriction information

This approach differs from existing solutions like EasyPark (which only covers their own parking areas) or Google Maps (which doesn't provide detailed parking restrictions).

## How We Plan to Meet Each Rubric Criterion

### Implementation Quality (10 points)
We're implementing a professional development workflow with CI/CD pipelines, mandatory code reviews, and comprehensive testing. Our Flutter app will follow clean architecture principles with the BLoC pattern for state management, ensuring readable and maintainable code. We'll use automated linting, formatting tools, and establish coding standards that all team members follow. The codebase will include comprehensive documentation and follow industry best practices for mobile app development.

### Implementation Sensors (10 points)
Our app integrates multiple sensors working together. The camera captures parking sign images for computer vision processing. GPS provides precise location data for finding nearby parking and determining user position relative to parking spots. The accelerometer detects when the user's car has stopped moving, indicating they've parked, which helps update spot availability. Bluetooth integration with car systems can automate parking session start/end detection. This multi-sensor approach demonstrates advanced understanding of how different sensors can work together to create a cohesive user experience.

### Implementation Connectivity (12 points)
We're using Microsoft Azure as our cloud platform to store and manage the parking database. The app connects to City of Melbourne's public parking APIs to seed our database with official parking information. Real-time connectivity enables live updates of parking availability as users report spots becoming free or occupied. We'll implement offline functionality with background synchronization, ensuring the app works even with poor connectivity. The cloud architecture supports scalability as our user base and data grow.

### Implementation Responsiveness (6 points)
Using Flutter's BLoC state management pattern with Cubit, our UI reactively updates based on sensor data and external information. When users take photos of parking signs, they see real-time processing indicators. The app dynamically updates parking availability based on sensor fusion (GPS + accelerometer + Bluetooth). Location-based features automatically refresh as users move around the city. The interface adapts to different data states - loading, error, success - providing clear feedback throughout all operations.

### Implementation Technical Depth (6 points)
Our app demonstrates technical sophistication through several advanced algorithms. Computer vision algorithms process parking sign images using OCR and text recognition to extract restriction information. Geospatial algorithms calculate proximity, walking distances, and optimal parking recommendations based on user destination. Privacy protection techniques ensure user location data is handled securely, with options for anonymous usage. Navigation algorithms consider real-time traffic, parking availability, and user preferences to suggest optimal routes and parking strategies.

### User Interface Appeal (4 points)
We're creating a visually appealing interface that feels modern and professional. Our design process includes studying successful navigation and parking apps like Google Maps, Waze, and EasyPark to understand what works well. We're creating detailed Figma prototypes and conducting user interviews to ensure our design resonates with users. The visual design emphasizes clarity and ease of use while maintaining an attractive, contemporary appearance that users will enjoy using.

### User Interface Guidelines (6 points)
Since we're developing for iOS, we'll strictly follow Apple's Human Interface Guidelines. This includes using standard iOS navigation patterns, respecting safe areas, implementing proper touch targets, and using system fonts and colors appropriately. We'll ensure our app feels native to iOS users by following established conventions for buttons, menus, gestures, and navigation flows. Accessibility will be built in from the start, supporting VoiceOver, Dynamic Type, and other iOS accessibility features.

### User Interface Flow (6 points)
Our app design prioritizes intuitive user flows based on real-world parking scenarios. Users can quickly access core features - finding parking or reporting a spot - with minimal taps. We're applying established UX principles like progressive disclosure to avoid overwhelming users with too many options at once. The information architecture follows logical patterns that users expect from navigation apps. Error states and edge cases are handled gracefully with clear recovery paths.

### User Interface Language (4 points)
We're implementing proper L10n (localization) to support multiple languages, starting with English and expanding based on user demographics. All text is clear, concise, and action-oriented. We're conducting user testing to ensure our terminology makes sense to real users. Labels and messages provide context without being verbose, and error messages are helpful rather than technical. The language feels natural and conversational while remaining professional.

### User Interface Reactiveness (6 points)
The interface dynamically responds to sensor input and external data changes. When GPS detects the user is moving, the app updates nearby parking options in real-time. Camera input immediately triggers processing indicators and shows progress as sign recognition occurs. Location-based features automatically update content as users navigate through different areas. The app provides immediate feedback for all user actions, creating a responsive and engaging experience.

### Innovation Novelty (3 points)
Most existing parking apps either focus only on paid parking (EasyPark) or don't provide detailed restriction information (Google Maps). Our crowd-sourced approach creates a comprehensive database of on-street parking restrictions that benefits the entire community. The computer vision component allows users to easily contribute data by simply taking photos, making data collection effortless. This combination of community participation and advanced technology creates a novel solution to urban parking challenges.

### Innovation Surprise (3 points)
Our app extends beyond traditional parking apps by turning every user into a data contributor. The gamification elements with incentives for photo submissions create unexpected engagement. Real-time parking availability updates based on sensor detection (knowing when cars actually leave spots) provides more accurate information than static databases. The combination of navigation assistance with detailed restriction analysis offers a comprehensive parking solution that doesn't currently exist in the market.

### Innovation Tech Knowledge (4 points)
The app demonstrates integration of multiple computing domains. Computer vision processes parking sign images and extracts structured data. Geospatial computing handles location-based search and proximity calculations. Privacy engineering protects sensitive user location data while still enabling useful features. Cloud computing provides scalable infrastructure for data storage and processing. Machine learning improves sign recognition accuracy over time through user feedback.

### Innovation Cross-Disciplinary (3 points)
Our project connects computing with urban planning by addressing real city infrastructure challenges. We're applying behavioral psychology principles to encourage user participation through thoughtful incentive design. Transportation engineering concepts inform our understanding of traffic flow and parking demand patterns. The app considers environmental impact by potentially reducing time spent searching for parking, which decreases emissions.

### Innovation Impact (3 points)
SmartPark has genuine potential to improve daily urban life. Reducing time spent searching for parking decreases stress, saves fuel, and reduces traffic congestion. Helping users understand parking restrictions prevents tickets and fines. The crowd-sourced data model creates a public good that benefits everyone, not just paying customers of commercial parking companies. For users with accessibility needs, detailed restriction information helps them find appropriate parking more easily.

## Development Approach

We're taking an iterative approach to development, starting with core functionality and gradually adding advanced features. Early prototypes will focus on the computer vision components since they're technically challenging and central to our value proposition. We plan regular user testing sessions to validate our design decisions and ensure we're building something people actually want to use.

This checkpoint represents our current planning, and we expect to refine details as we begin implementation and learn more about technical constraints and user needs.
