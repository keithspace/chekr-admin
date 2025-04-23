import { serve } from "https://deno.land/std/http/server.ts";
import { createClient } from "jsr:@supabase/supabase-js@2"


const supabaseUrl = Deno.env.get("SUPABASE_URL");//https://wlbdvdbnecfwmxxftqrk.supabase.co
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");//eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndsYmR2ZGJuZWNmd214eGZ0cXJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzg3NDcyNDcsImV4cCI6MjA1NDMyMzI0N30.JUKAxGQe8O57rb2kkZ6KUOEGi6RTiCQv34mAgUlHals
const supabase = createClient(supabaseUrl, supabaseKey);

// Firestore API URL and credentials
const firestoreUrl = "https://firestore.googleapis.com/v1/projects/chekr1/databases/(default)/documents/";

// This will handle the POST request from M-Pesa STK Push callback
serve(async (req) => {
  if (req.method === "POST") {
    const data = await req.json();

    // Validate the data here
    if (data && data.Body) {
      const paymentStatus = data.Body.stkCallback.ResultCode;

      // Handle the result and update Supabase
      if (paymentStatus === 0) {
        // Payment was successful, log it
        console.log("Payment was successful");

        const transactionDetails = data.Body.stkCallback.CallbackMetadata.Item;

        // Extract information like amount, phone number, etc.
        const amount = transactionDetails.find(item => item.Name === "Amount")?.Value;
        const phoneNumber = transactionDetails.find(item => item.Name === "PhoneNumber")?.Value;
        const userId = "user-id";  // Replace with the actual userId from your app
        const cartId = "cart-id";  // Replace with the actual cartId

        // Fetch cart data from Firestore using the REST API
        const cartResponse = await fetch(`${firestoreUrl}customers/${userId}/cart/${cartId}`);
        const cartDoc = await cartResponse.json();

        if (!cartDoc.fields) {
          console.log("Cart not found");
          return new Response("Cart not found", { status: 400 });
        }

        const cartData = cartDoc.fields;

        // Extract products from Firestore cart data
        const products = cartData.products || [];

        // Create order data for Supabase
        const { data: orderData, error: orderError } = await supabase
          .from("orders")
          .insert([{
            cart_id: cartId,
            user_id: userId,
            payment_mode: "M-Pesa",
            amount_paid: amount,
            phone_number: phoneNumber,
            status: "Paid",  // Update order status to paid
            timestamp: new Date().toISOString(),
            products: products,  // Add product details here from the cart
          }]);

        if (orderError) {
          console.log("Order creation error: ", orderError.message);
          return new Response("Error creating order", { status: 500 });
        }

        console.log("Order created successfully in Supabase");
      } else {
        // Payment failed
        console.log("Payment failed");
      }
    } else {
      console.log("Invalid data received");
    }

    // Respond back to M-Pesa
    return new Response(JSON.stringify({ status: "success" }), {
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  }

  return new Response("Invalid request", { status: 400 });
});